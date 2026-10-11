-- Velora Jam Co. - client core: player ready, business NPC, shifts, vans, blips, admin helpers
VJC = {}

function VJC.notify(description, ntype, title)
    lib.notify({
        title = title or Config.BusinessName,
        description = description,
        type = ntype or 'inform',
        icon = 'jar',
        iconColor = '#f06aa6',
    })
end

function VJC.playAnim(dict, clip, flag)
    if not dict then return end
    lib.requestAnimDict(dict, 5000)
    TaskPlayAnim(cache.ped, dict, clip, 3.0, 3.0, -1, flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
end

function VJC.stopAnim()
    ClearPedTasks(cache.ped)
end

function VJC.blip(coords, cfg, label)
    if not cfg or not cfg.enabled then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.colour)
    SetBlipScale(blip, cfg.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- Polls fn until it returns a value or the timeout passes (never throws)
function VJC.waitFor(fn, timeout)
    local deadline = GetGameTimer() + (timeout or 5000)
    while GetGameTimer() < deadline do
        local value = fn()
        if value then return value end
        Wait(50)
    end
    return nil
end

-- Busy guard shared by every activity so two UIs / minigames never overlap
VJC.busy = false

function VJC.canStart()
    if VJC.busy or Nui.isOpen() then return false end
    if IsPedInAnyVehicle(cache.ped, false) then
        VJC.notify('Get out of the vehicle first.', 'error')
        return false
    end
    if IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped) then return false end
    return true
end

-- ─────────────────────────────────────────────────────────────────────────
-- Player ready (login + resource restart recovery)
-- ─────────────────────────────────────────────────────────────────────────
local function ready()
    TriggerServerEvent('velora_jamco:server:ready')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2000, ready)
end)

AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then SetTimeout(1500, ready) end
end)

RegisterNetEvent('velora_jamco:client:achievements', function(list)
    Nui.send('achievements', list)
    for _, ach in ipairs(list) do
        PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_MINI_GAME_SOUNDSET', true)
        VJC.notify(ach.description, 'success', 'Achievement: ' .. ach.label)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Business NPC
-- ─────────────────────────────────────────────────────────────────────────
local npcCfg = Config.Business.npc
local npcPed = nil

local function openBusiness()
    if not VJC.canStart() then return end
    local data = lib.callback.await('velora_jamco:business:getData', false)
    if not data then return end
    data.vans = Config.Van.Models
    data.colours = Config.Van.Colours
    data.fruitsCfg = Config.Fruits
    data.fruitOrder = Config.FruitOrder
    data.specialsCfg = Config.Specials
    data.specialOrder = Config.SpecialOrder
    data.supplies = Config.Supplies
    data.businessName = Config.BusinessName
    Nui.open('business', data)
end

local function openShop()
    if lib.callback.await('velora_jamco:business:openShop', false) then
        exports.ox_inventory:openInventory('shop', { type = 'velora_jamco_supplies', id = 1 })
    else
        VJC.notify('The pantry is closed right now.', 'error')
    end
end

local function spawnNpc()
    if npcPed and DoesEntityExist(npcPed) then return end
    local model = GetHashKey(npcCfg.model)
    lib.requestModel(model, 10000)
    npcPed = CreatePed(4, model, npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z - 1.0, npcCfg.coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    SetPedCanRagdoll(npcPed, false)
    if npcCfg.scenario then TaskStartScenarioInPlace(npcPed, npcCfg.scenario, 0, true) end

    exports.ox_target:addLocalEntity(npcPed, {
        {
            name = 'velora_jamco_business',
            label = ('Talk to %s'):format(npcCfg.name),
            icon = 'fa-solid fa-jar',
            distance = Config.Business.interactDistance,
            onSelect = openBusiness,
        },
        {
            name = 'velora_jamco_shop',
            label = 'Pantry Supplies',
            icon = 'fa-solid fa-basket-shopping',
            distance = Config.Business.interactDistance,
            canInteract = function() return Config.Shop.enabled end,
            onSelect = openShop,
        },
    })
end

local function deleteNpc()
    if npcPed and DoesEntityExist(npcPed) then
        exports.ox_target:removeLocalEntity(npcPed)
        DeletePed(npcPed)
    end
    npcPed = nil
end

lib.points.new({
    coords = vec3(npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z),
    distance = 60.0,
    onEnter = spawnNpc,
    onExit = deleteNpc,
})

CreateThread(function()
    VJC.blip(npcCfg.coords, Config.Business.blip, Config.BusinessName)
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Business NUI actions
-- ─────────────────────────────────────────────────────────────────────────
local function setVanFuel(veh)
    local fuel = Config.VanFuel
    if GetResourceState('LegacyFuel') == 'started' then
        pcall(function() exports.LegacyFuel:SetFuel(veh, fuel) end)
    elseif GetResourceState('cdn-fuel') == 'started' then
        pcall(function() exports['cdn-fuel']:SetFuel(veh, fuel) end)
    elseif GetResourceState('ps-fuel') == 'started' then
        pcall(function() exports['ps-fuel']:SetFuel(veh, fuel) end)
    end
    SetVehicleFuelLevel(veh, fuel)
end

RegisterNUICallback('business:startShift', function(data, cb)
    local res = lib.callback.await('velora_jamco:business:startShift', false, data)
    if res and res.ok and res.netId then
        local veh = VJC.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(res.netId) then
                local ent = NetworkGetEntityFromNetworkId(res.netId)
                if ent ~= 0 then return ent end
            end
        end, 8000)
        if veh then
            setVanFuel(veh)
            SetVehicleDirtLevel(veh, 0.0)
            SetVehicleOnGroundProperly(veh)
            local c = GetEntityCoords(veh)
            SetNewWaypoint(c.x, c.y)
        end
    end
    if res and res.ok then
        VJC.notify(res.netId and ('Your van (%s) is parked out front. Have a lovely shift!'):format(res.plate) or 'Shift started. Happy picking!', 'success')
    end
    cb(res or { ok = false, msg = 'No response.' })
end)

RegisterNUICallback('business:endShift', function(data, cb)
    local res = lib.callback.await('velora_jamco:business:endShift', false, data and data.forfeit == true)
    if res and res.ok then VJC.notify(res.msg, 'success') end
    cb(res or { ok = false, msg = 'No response.' })
end)

RegisterNUICallback('business:waypoint', function(data, cb)
    cb(1)
    if type(data) == 'table' and tonumber(data.x) and tonumber(data.y) then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
        VJC.notify('Waypoint set.', 'inform')
    end
end)

RegisterNUICallback('business:shop', function(_, cb)
    cb(1)
    Nui.close()
    Wait(150)
    openShop()
end)

-- Key systems that only work client-side
RegisterNetEvent('velora_jamco:client:giveKeys', function(netId, plate)
    local veh = VJC.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 then return ent end
        end
    end, 8000)
    if not veh then return end
    local system = Config.VehicleKeys
    if system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(veh)), true) end)
    elseif system == 'wasabi_carlock' then
        pcall(function() exports.wasabi_carlock:GiveKey(plate) end)
    elseif system == 'MrNewbVehicleKeys' then
        pcall(function() exports.MrNewbVehicleKeys:GiveKeys(veh) end)
    end
end)

RegisterNetEvent('velora_jamco:client:removeKeys', function(plate)
    local system = Config.VehicleKeys
    if system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:RemoveKeys(plate, 'speedo') end)
    elseif system == 'wasabi_carlock' then
        pcall(function() exports.wasabi_carlock:RemoveKey(plate) end)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Admin helpers (server restricts who can trigger these)
-- ─────────────────────────────────────────────────────────────────────────
RegisterNetEvent('velora_jamco:client:copyCoords', function(kind, fruit)
    local c = GetEntityCoords(cache.ped)
    local h = GetEntityHeading(cache.ped)
    local text
    if kind == 'tree' then
        local isBush = fruit == 'strawberry' or fruit == 'blueberry' or fruit == 'blackberry' or fruit == 'raspberry'
        local id = ('tree_%s_%d'):format(fruit, GetGameTimer() % 100000)
        text = ("%s('%s', '%s', %.2f, %.2f, %.2f),"):format(isBush and 'bush' or 'tree', id, fruit, c.x, c.y, c.z)
    else
        text = ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)
    end
    lib.setClipboard(text)
    print('[velora_jamco] ' .. text)
    VJC.notify('Copied to clipboard: ' .. text, 'success')
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    deleteNpc()
end)
