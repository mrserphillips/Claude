-- Velora Jam Co. - jam kitchen stations and crafting bridge
local Props = {}       -- kitchen id -> stove prop
local crafting = nil   -- { token, kitchen }
local activeKitchen = nil

local function stopCrafting(sendCancel)
    if crafting and sendCancel then
        local token = crafting.token
        lib.callback('velora_jamco:craft:cancel', false, function(res)
            if res and res.refundedAll then
                VJC.notify('Batch abandoned - your ingredients were returned.', 'inform')
            else
                VJC.notify('Batch abandoned. The unused jars and lids were returned.', 'inform')
            end
        end, token)
    end
    if crafting then VJC.stopAnim() end
    crafting = nil
end

Nui.onClose('kitchen', function()
    stopCrafting(true)
    activeKitchen = nil
    VJC.busy = false
end)

local function monitor(kitchen)
    CreateThread(function()
        while activeKitchen == kitchen do
            Wait(300)
            if activeKitchen ~= kitchen then break end
            local ped = cache.ped
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false)
                or #(GetEntityCoords(ped) - kitchen.coords) > kitchen.maxDistance then
                if Nui.app == 'kitchen' then Nui.close() end
                VJC.notify('You stepped away from the stove.', 'error')
                break
            end
        end
    end)
end

local function openKitchen(kitchen)
    if not VJC.canStart() then return end
    VJC.busy = true
    local data = lib.callback.await('velora_jamco:kitchen:getData', false)
    if not data or data.error then
        VJC.busy = false
        return VJC.notify(data and data.error or 'The kitchen is unavailable.', 'error')
    end
    activeKitchen = kitchen
    data.kitchen = kitchen.label
    data.rarities = Config.Rarities
    data.tiers = Config.QualityTiers
    Nui.open('kitchen', data)
    monitor(kitchen)
end

RegisterNUICallback('kitchen:start', function(data, cb)
    if not activeKitchen or crafting then return cb({ ok = false, msg = 'You are already cooking.' }) end
    local res = lib.callback.await('velora_jamco:craft:start', false, data)
    if res and res.ok then
        crafting = { token = res.token }
        local c = activeKitchen.coords
        TaskTurnPedToFaceCoord(cache.ped, c.x, c.y, c.z, 600)
        Wait(600)
        local anim = activeKitchen.anim
        if anim then VJC.playAnim(anim.dict, anim.clip, 1) end
    end
    cb(res or { ok = false, msg = 'No response.' })
end)

RegisterNUICallback('kitchen:stage', function(data, cb)
    if not crafting or type(data) ~= 'table' then return cb({ ok = false, ended = true, msg = 'No batch in progress.' }) end
    local res = lib.callback.await('velora_jamco:craft:stage', false, crafting.token, data.stage, data.data)
    if res and (res.finished or res.ended) then
        stopCrafting(false)
        if res.finished and res.finished.ok then
            PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
        end
    end
    cb(res or { ok = false, msg = 'No response.' })
end)

RegisterNUICallback('kitchen:cancel', function(_, cb)
    stopCrafting(true)
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Stations
-- ─────────────────────────────────────────────────────────────────────────
for _, kitchen in ipairs(Config.Kitchens) do
    exports.ox_target:addSphereZone({
        coords = kitchen.coords,
        radius = kitchen.radius or 1.0,
        debug = Config.Debug,
        options = {
            {
                name = 'velora_jamco_kitchen_' .. kitchen.id,
                label = 'Use Jam Kitchen',
                icon = 'fa-solid fa-fire-burner',
                iconColor = '#f06aa6',
                distance = 2.0,
                canInteract = function() return not VJC.busy end,
                onSelect = function() openKitchen(kitchen) end,
            },
        },
    })

    VJC.blip(kitchen.coords, kitchen.blip, kitchen.label)

    if kitchen.prop and kitchen.prop.model then
        local p = kitchen.prop
        lib.points.new({
            coords = vec3(p.coords.x, p.coords.y, p.coords.z),
            distance = 60.0,
            onEnter = function()
                if Props[kitchen.id] and DoesEntityExist(Props[kitchen.id]) then return end
                local hash = GetHashKey(p.model)
                if not IsModelInCdimage(hash) or not pcall(lib.requestModel, hash, 8000) then
                    return print(('^1[velora_jamco] kitchen prop %s could not be loaded^7'):format(p.model))
                end
                local obj = CreateObject(hash, p.coords.x, p.coords.y, p.coords.z, false, false, false)
                SetModelAsNoLongerNeeded(hash)
                SetEntityHeading(obj, p.coords.w)
                FreezeEntityPosition(obj, true)
                Props[kitchen.id] = obj
            end,
            onExit = function()
                local obj = Props[kitchen.id]
                if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
                Props[kitchen.id] = nil
            end,
        })
    end
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id, obj in pairs(Props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        Props[id] = nil
    end
    if crafting then VJC.stopAnim() end
end)
