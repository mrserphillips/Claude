local propObject = nil

local function CreateGiveawayProp()
    local model = Config.Prop.model
    lib.requestModel(model)

    propObject = CreateObject(model, Config.Prop.coords.x, Config.Prop.coords.y, Config.Prop.coords.z, false, false, false)
    SetEntityHeading(propObject, Config.Prop.heading)
    PlaceObjectOnGroundProperly(propObject)
    FreezeEntityPosition(propObject, true)
    SetEntityAsMissionEntity(propObject, true, true)
    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(propObject, {
        {
            name = 'giveaway_signup',
            icon = Config.Target.icon,
            label = Config.Target.label,
            distance = Config.Target.distance,
            onSelect = function()
                TriggerServerEvent('giveaway:server:signup')
            end,
        },
    })
end

CreateThread(function()
    CreateGiveawayProp()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if propObject and DoesEntityExist(propObject) then
        exports.ox_target:removeLocalEntity(propObject, 'giveaway_signup')
        DeleteEntity(propObject)
    end
end)

RegisterNetEvent('giveaway:client:spin', function(entrants, winnerIndex, durationMs)
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
