-- Velora Jam Co. - /selljam: customers walk up to you, you serve them, they buy 1-3 jars
--
-- The server decides WHEN a customer is due (velora_jamco:sell:request) and validates every sale.
-- The customer ped itself is local to the seller (never networked), so it never touches the
-- city population and only one exists per seller at a time.
local CFG = Config.Selling
local selling = false
local customer = nil   -- { token, name, ped, blip, state = 'walking'|'waiting'|'serving', since, sold }
local promptShown = false

local function hidePrompt()
    if promptShown then
        lib.hideTextUI()
        promptShown = false
    end
end

local function showPrompt(name)
    if not promptShown then
        lib.showTextUI(('[E] Serve %s'):format(name), { position = 'left-center', icon = 'jar', iconColor = '#f06aa6' })
        promptShown = true
    end
end

local function distanceTo(ped)
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(ped))
end

-- Send the current customer away (optionally telling the server they left without buying)
local function leave(reason, notifyServer)
    local c = customer
    if not c then return end
    customer = nil
    hidePrompt()
    if notifyServer then lib.callback('velora_jamco:sell:dismiss', false, function() end, c.token) end
    if reason then VJC.notify(reason, 'inform') end
    if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) end
    local ped = c.ped
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped)
        ClearPedTasks(ped)
        SetBlockingOfNonTemporaryEvents(ped, false)
        TaskWanderStandard(ped, 10.0, 10)
        SetPedKeepTask(ped, true)
        CreateThread(function()
            local deadline = GetGameTimer() + 20000
            while DoesEntityExist(ped) and GetGameTimer() < deadline and #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) < 60.0 do
                Wait(1000)
            end
            if DoesEntityExist(ped) then DeletePed(ped) end
        end)
    end
end

local function gesture(ped, dict, clip)
    if not ped or not DoesEntityExist(ped) then return end
    lib.requestAnimDict(dict, 3000)
    TaskPlayAnim(ped, dict, clip, 4.0, 4.0, 2500, 48, 0, false, false, false)
    RemoveAnimDict(dict)
end

-- ─────────────────────────────────────────────────────────────────────────
-- Serving
-- ─────────────────────────────────────────────────────────────────────────
local function serve()
    local c = customer
    if not c or c.state == 'serving' then return end
    if Nui.isOpen() or VJC.busy then return end
    if IsPedInAnyVehicle(cache.ped, false) then return VJC.notify('Get out of the vehicle first.', 'error') end
    c.state = 'serving'
    hidePrompt()
    VJC.busy = true
    local res = lib.callback.await('velora_jamco:sell:serve', false, c.token)
    if customer ~= c then VJC.busy = false return end
    if not res or not res.ok then
        VJC.busy = false
        return leave(res and res.msg or 'The customer wandered off.', false)
    end
    if DoesEntityExist(c.ped) then
        ClearPedTasks(c.ped)
        TaskTurnPedToFaceEntity(c.ped, cache.ped, -1)
    end
    TaskTurnPedToFaceEntity(cache.ped, c.ped, 1000)
    Nui.open('sell', res)
end

Nui.onClose('sell', function()
    VJC.busy = false
    local c = customer
    if c and c.state == 'serving' then
        -- a finished sale already cleared the visit server-side; otherwise they leave unhappy
        leave(nil, not c.sold)
    end
end)

local function handoff(ped)
    lib.requestAnimDict('mp_common', 3000)
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, 8.0, 2000, 48, 0, false, false, false)
    if ped and DoesEntityExist(ped) then
        TaskPlayAnim(ped, 'mp_common', 'givetake1_b', 8.0, 8.0, 2000, 48, 0, false, false, false)
    end
    RemoveAnimDict('mp_common')
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
end

local function sellCall(name, arg, cb)
    local res = lib.callback.await('velora_jamco:sell:' .. name, false, arg)
    local c = customer
    if res and res.sold then
        if c then c.sold = true end
        handoff(c and c.ped)
        if not res.sellingActive then selling = false end
    elseif res and res.ended and c then
        c.sold = true -- server already closed the visit
        gesture(c.ped, 'gestures@m@standing@casual', 'gesture_bye_soft')
    end
    cb(res or { ok = false, msg = 'No response.' })
end

RegisterNUICallback('sell:offer', function(data, cb) sellCall('offer', data and data.slot, cb) end)
RegisterNUICallback('sell:pitch', function(data, cb) sellCall('pitch', data and data.pitch, cb) end)
RegisterNUICallback('sell:counter', function(data, cb) sellCall('counter', data and data.amount, cb) end)
RegisterNUICallback('sell:accept', function(_, cb) sellCall('accept', nil, cb) end)

-- ─────────────────────────────────────────────────────────────────────────
-- Spawning a customer who walks over
-- ─────────────────────────────────────────────────────────────────────────
local function findSpawn()
    local origin = GetEntityCoords(cache.ped)
    for _ = 1, 12 do
        local angle = math.random() * math.pi * 2
        local dist = math.random(CFG.SpawnDistance[1], CFG.SpawnDistance[2])
        local x, y = origin.x + math.cos(angle) * dist, origin.y + math.sin(angle) * dist
        local found, safe = GetSafeCoordForPed(x, y, origin.z, false, 16)
        if found and math.abs(safe.z - origin.z) < 8.0 then return safe end
    end
    for _ = 1, 8 do
        local angle = math.random() * math.pi * 2
        local dist = math.random(CFG.SpawnDistance[1], CFG.SpawnDistance[2])
        local x, y = origin.x + math.cos(angle) * dist, origin.y + math.sin(angle) * dist
        local found, z = GetGroundZFor_3dCoord(x, y, origin.z + 3.0, false)
        if found and math.abs(z - origin.z) < 5.0 then return vec3(x, y, z) end
    end
    -- last resort: just around the corner from the player
    return vec3(origin.x + 8.0, origin.y + 8.0, origin.z - 1.0)
end

local function spawnCustomer(res)
    local hash = GetHashKey(res.model)
    if not IsModelInCdimage(hash) then hash = GetHashKey('a_f_y_hipster_01') end
    if not pcall(lib.requestModel, hash, 8000) then
        lib.callback('velora_jamco:sell:dismiss', false, function() end, res.token)
        return
    end
    local pos = findSpawn()
    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 then
        lib.callback('velora_jamco:sell:dismiss', false, function() end, res.token)
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedKeepTask(ped, true)
    TaskGoToEntity(ped, cache.ped, -1, CFG.ServeDistance - 1.0, 1.25, 1073741824, 0)

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 48)
    SetBlipScale(blip, 0.7)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Jam Customer')
    EndTextCommandSetBlipName(blip)

    customer = { token = res.token, name = res.name, ped = ped, blip = blip, state = 'walking', since = GetGameTimer(), sold = false }
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'velora_jamco_serve',
            label = ('Serve %s'):format(res.name),
            icon = 'fa-solid fa-jar',
            iconColor = '#f06aa6',
            distance = CFG.ServeDistance + 0.5,
            canInteract = function() return customer and customer.ped == ped and customer.state ~= 'serving' end,
            onSelect = serve,
        },
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    VJC.notify(('%s spotted your jam and is coming over.'):format(res.name), 'inform', 'Customer')
end

-- Runs while the customer is walking over or waiting; returns the wait for the next tick
local function updateCustomer()
    local c = customer
    local ped = c.ped
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
        leave('Your customer is gone.', true)
        return 500
    end
    if c.state == 'serving' then return 500 end
    if IsPedInAnyVehicle(cache.ped, false) or IsEntityDead(cache.ped) then
        leave('Your customer gave up - you drove off.', true)
        return 500
    end

    local dist = distanceTo(ped)
    local now = GetGameTimer()
    if c.state == 'walking' then
        if dist <= CFG.ServeDistance then
            c.state = 'waiting'
            c.since = now
            ClearPedTasks(ped)
            TaskTurnPedToFaceEntity(ped, cache.ped, -1)
            gesture(ped, 'gestures@f@standing@casual', 'gesture_hello')
        elseif now - c.since > CFG.ArriveTimeout * 1000 then
            leave('The customer could not reach you.', true)
            return 500
        elseif dist > 80.0 then
            leave('You left your customer behind.', true)
            return 500
        end
        return 250
    end

    -- waiting beside the player
    if dist > CFG.ServeDistance + 3.0 then
        hidePrompt()
        c.state = 'walking'
        c.since = now
        TaskGoToEntity(ped, cache.ped, -1, CFG.ServeDistance - 1.0, 1.25, 1073741824, 0)
        return 250
    end
    if now - c.since > CFG.WaitTimeout * 1000 then
        leave(('%s got tired of waiting.'):format(c.name), true)
        return 500
    end
    if dist <= CFG.ServeDistance + 0.75 and not Nui.isOpen() and not VJC.busy then
        showPrompt(c.name)
        if IsControlJustPressed(0, CFG.ServeKey) then serve() end
        return 0
    end
    hidePrompt()
    return 100
end

local function sellingLoop()
    CreateThread(function()
        while selling do
            local waitMs = 1000
            if customer then
                waitMs = updateCustomer()
            elseif not Nui.isOpen() and not VJC.busy and not IsPedInAnyVehicle(cache.ped, false) and not IsEntityDead(cache.ped) then
                local res = lib.callback.await('velora_jamco:sell:request', false)
                if not selling then break end
                if res and res.stop then
                    selling = false
                    if res.msg then VJC.notify(res.msg, 'inform') end
                elseif res and res.ok then
                    spawnCustomer(res)
                else
                    waitMs = math.floor(math.max(1, math.min(res and res.retryIn or 5, 10)) * 1000)
                end
            end
            Wait(waitMs)
        end
        if customer and customer.state ~= 'serving' then leave(nil, true) end
        hidePrompt()
    end)
end

-- ─────────────────────────────────────────────────────────────────────────
-- /selljam toggles selling mode
-- ─────────────────────────────────────────────────────────────────────────
RegisterCommand(CFG.Command, function()
    if customer and customer.state == 'serving' then return end
    if not selling and IsPedInAnyVehicle(cache.ped, false) then
        return VJC.notify('You cannot sell from a vehicle.', 'error')
    end
    local res = lib.callback.await('velora_jamco:sell:toggle', false)
    if not res then return end
    local wasSelling = selling
    selling = res.active
    VJC.notify(res.msg, res.active and 'success' or 'inform')
    if selling and not wasSelling then sellingLoop() end
    if not selling and customer then leave(nil, false) end
end, false)

TriggerEvent('chat:addSuggestion', '/' .. CFG.Command, 'Start or stop selling Velora jam - customers will come to you')

RegisterNetEvent('velora_jamco:client:sellingState', function(state)
    if selling and not state then VJC.notify('Selling mode ended - you are out of jam.', 'inform') end
    selling = state
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    hidePrompt()
    if customer then
        if customer.blip and DoesBlipExist(customer.blip) then RemoveBlip(customer.blip) end
        if DoesEntityExist(customer.ped) then DeletePed(customer.ped) end
        customer = nil
    end
end)
