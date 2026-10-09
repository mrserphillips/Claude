local baseObject = nil
local wheelObject = nil
local isAdmin = false
local wheelRoll = 0.0

local TARGET_NAMES = { 'giveaway_signup', 'giveaway_spin', 'giveaway_list', 'giveaway_clear' }

-- Ask the server once whether we're an admin so the admin target options can be hidden
-- from everyone else. The server re-checks on every action, so this is only cosmetic.
local function RefreshAdmin()
    isAdmin = lib.callback.await('giveaway:server:isAdmin', false) == true
end

local function AdminOnly()
    return isAdmin
end

local function SpawnObject(model, coords, heading)
    lib.requestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function SetWheelRoll(roll)
    -- rotation order 2 applies the roll in the wheel's own frame before the heading,
    -- so the disc spins around its axle whatever way the base is facing
    SetEntityRotation(wheelObject, 0.0, roll, Config.Prop.heading, 2, true)
end

local function CreateGiveawayProp()
    baseObject = SpawnObject(Config.Prop.model, Config.Prop.coords, Config.Prop.heading)
    if Config.Prop.placeOnGround then
        PlaceObjectOnGroundProperly(baseObject)
    end

    local targetEntities = { baseObject }

    if Config.Wheel.enabled then
        local o = Config.Wheel.offset
        local pos = GetOffsetFromEntityInWorldCoords(baseObject, o.x, o.y, o.z)
        wheelObject = SpawnObject(Config.Wheel.model, pos, Config.Prop.heading)
        SetWheelRoll(wheelRoll)
        targetEntities[#targetEntities + 1] = wheelObject
    end

    local t = Config.Target
    exports.ox_target:addLocalEntity(targetEntities, {
        {
            name = 'giveaway_signup',
            icon = t.signup.icon,
            label = t.signup.label,
            distance = t.distance,
            onSelect = function()
                TriggerServerEvent('giveaway:server:signup')
            end,
        },
        {
            name = 'giveaway_spin',
            icon = t.spin.icon,
            label = t.spin.label,
            distance = t.distance,
            canInteract = AdminOnly,
            onSelect = function()
                TriggerServerEvent('giveaway:server:spin')
            end,
        },
        {
            name = 'giveaway_list',
            icon = t.list.icon,
            label = t.list.label,
            distance = t.distance,
            canInteract = AdminOnly,
            onSelect = function()
                TriggerServerEvent('giveaway:server:list')
            end,
        },
        {
            name = 'giveaway_clear',
            icon = t.clear.icon,
            label = t.clear.label,
            distance = t.distance,
            canInteract = AdminOnly,
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Clear Giveaway',
                    content = 'Remove everyone from the sign-up list?',
                    centered = true,
                    cancel = true,
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('giveaway:server:clear')
                end
            end,
        },
    })
end

-- Spins the physical disc on the prop over the same duration as the on-screen wheel.
-- Purely visual: the winner is decided server-side and shown in the NUI.
local function SpinPhysicalWheel(entrantCount, winnerIndex, durationMs)
    if not wheelObject or not DoesEntityExist(wheelObject) then return end

    local startRoll = wheelRoll % 360.0
    local segment = 360.0 / entrantCount
    local endRoll = startRoll + Config.Wheel.fullSpins * 360.0 + (winnerIndex - 0.5) * segment

    CreateThread(function()
        local startTime = GetGameTimer()
        while true do
            local t = math.min((GetGameTimer() - startTime) / durationMs, 1.0)
            local eased = 1.0 - (1.0 - t) ^ 4 -- ease-out to roughly match the NUI wheel
            wheelRoll = startRoll + (endRoll - startRoll) * eased
            if not DoesEntityExist(wheelObject) then return end
            SetWheelRoll(wheelRoll)
            if t >= 1.0 then break end
            Wait(0)
        end
    end)
end

CreateThread(function()
    CreateGiveawayProp()
    RefreshAdmin()
end)

-- permissions can change on character load (qbx_core), so re-check then too
RegisterNetEvent('QBX:Client:OnPlayerLoaded', RefreshAdmin)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local entities = { baseObject, wheelObject }
    for _, obj in pairs(entities) do
        if obj and DoesEntityExist(obj) then
            exports.ox_target:removeLocalEntity(obj, TARGET_NAMES)
            DeleteEntity(obj)
        end
    end
end)

RegisterNetEvent('giveaway:client:spin', function(entrants, winnerIndex, durationMs)
    SpinPhysicalWheel(#entrants, winnerIndex, durationMs)

    SendNUIMessage({
        action = 'spin',
        entrants = entrants,
        winnerIndex = winnerIndex,
        duration = durationMs,
    })

    SetTimeout(durationMs + 6000, function()
        SendNUIMessage({ action = 'hide' })
    end)
end)
