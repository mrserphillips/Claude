-- Velora Jam Co. - /selljam selling mode and customer conversations
local CFG = Config.Selling
local selling = false
local talking = nil   -- { ped, netId }

local function releasePed()
    if not talking then return end
    local ped = talking.ped
    talking = nil
    if DoesEntityExist(ped) then
        SetBlockingOfNonTemporaryEvents(ped, false)
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
    end
end

Nui.onClose('sell', function()
    if talking then lib.callback('velora_jamco:sell:cancel', false, function() end) end
    releasePed()
    VJC.busy = false
end)

local function controlPed(ped)
    local deadline = GetGameTimer() + 1000
    NetworkRequestControlOfEntity(ped)
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do
        Wait(50)
        NetworkRequestControlOfEntity(ped)
    end
    return NetworkHasControlOfEntity(ped)
end

local function gesture(ped, dict, clip)
    lib.requestAnimDict(dict, 3000)
    TaskPlayAnim(ped, dict, clip, 4.0, 4.0, 2500, 48, 0, false, false, false)
    RemoveAnimDict(dict)
end

local function monitor(ped)
    CreateThread(function()
        while talking and talking.ped == ped do
            Wait(300)
            if not talking then break end
            local me = cache.ped
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or IsEntityDead(me)
                or IsPedInAnyVehicle(me, false) or #(GetEntityCoords(me) - GetEntityCoords(ped)) > CFG.MaxDistance + 2.0 then
                if Nui.app == 'sell' then Nui.close() else releasePed() end
                VJC.notify('The conversation ended.', 'error')
                break
            end
        end
    end)
end

local function isCustomer(ped)
    return selling and not talking and not VJC.busy
        and not IsPedAPlayer(ped) and IsPedHuman(ped)
        and not IsPedDeadOrDying(ped, true)
        and not IsPedInAnyVehicle(ped, false)
        and not IsPedInAnyVehicle(cache.ped, false)
        and CFG.AllowedPopTypes[GetEntityPopulationType(ped)] == true
end

local function approach(ped)
    if not VJC.canStart() or talking then return end
    if not NetworkGetEntityIsNetworked(ped) then
        VJC.notify('They do not seem interested.', 'error')
        return
    end
    VJC.busy = true
    local netId = NetworkGetNetworkIdFromEntity(ped)
    local res = lib.callback.await('velora_jamco:sell:approach', false, netId)
    if not res or not res.ok then
        VJC.busy = false
        if res and res.rejected and controlPed(ped) then
            TaskTurnPedToFaceEntity(ped, cache.ped, 1500)
            gesture(ped, 'gestures@m@standing@casual', 'gesture_no_way')
        end
        return VJC.notify(res and res.msg or 'They are not interested.', res and res.rejected and 'warning' or 'error', res and res.rejected and 'Customer' or nil)
    end

    talking = { ped = ped, netId = netId }
    if controlPed(ped) then
        ClearPedTasks(ped)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskTurnPedToFaceEntity(ped, cache.ped, -1)
    end
    TaskTurnPedToFaceEntity(cache.ped, ped, 1000)
    Nui.open('sell', res)
    monitor(ped)
end

local function handoff()
    if not talking then return end
    local ped = talking.ped
    lib.requestAnimDict('mp_common', 3000)
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, 8.0, 2000, 48, 0, false, false, false)
    if DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) then
        TaskPlayAnim(ped, 'mp_common', 'givetake1_b', 8.0, 8.0, 2000, 48, 0, false, false, false)
    end
    RemoveAnimDict('mp_common')
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
end

local function sellCall(name, arg, cb)
    local res = lib.callback.await('velora_jamco:sell:' .. name, false, arg)
    if res and res.sold then
        handoff()
        if not res.sellingActive then selling = false end
    end
    if res and res.ended and not res.sold and talking and DoesEntityExist(talking.ped) and NetworkHasControlOfEntity(talking.ped) then
        gesture(talking.ped, 'gestures@m@standing@casual', 'gesture_bye_soft')
    end
    cb(res or { ok = false, msg = 'No response.' })
end

RegisterNUICallback('sell:offer', function(data, cb) sellCall('offer', data and data.slot, cb) end)
RegisterNUICallback('sell:pitch', function(data, cb) sellCall('pitch', data and data.pitch, cb) end)
RegisterNUICallback('sell:counter', function(data, cb) sellCall('counter', data and data.amount, cb) end)
RegisterNUICallback('sell:accept', function(_, cb) sellCall('accept', nil, cb) end)

-- ─────────────────────────────────────────────────────────────────────────
-- /selljam toggles selling mode
-- ─────────────────────────────────────────────────────────────────────────
RegisterCommand(CFG.Command, function()
    if talking then return end
    if not selling and IsPedInAnyVehicle(cache.ped, false) then
        return VJC.notify('You cannot sell from a vehicle.', 'error')
    end
    local res = lib.callback.await('velora_jamco:sell:toggle', false)
    if not res then return end
    selling = res.active
    VJC.notify(res.msg, res.active and 'success' or 'inform')
end, false)

TriggerEvent('chat:addSuggestion', '/' .. CFG.Command, 'Start or stop selling Velora jam to locals')

RegisterNetEvent('velora_jamco:client:sellingState', function(state)
    if selling and not state then VJC.notify('Selling mode ended - you are out of jam.', 'inform') end
    selling = state
end)

exports.ox_target:addGlobalPed({
    {
        name = 'velora_jamco_sell',
        label = 'Offer Velora Jam',
        icon = 'fa-solid fa-jar',
        iconColor = '#f06aa6',
        distance = CFG.InteractDistance,
        canInteract = function(entity) return isCustomer(entity) end,
        onSelect = function(data) approach(data.entity) end,
    },
})

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    exports.ox_target:removeGlobalPed('velora_jamco_sell')
    releasePed()
end)
