MJC = MJC or {}
MJC.Client = MJC.Client or {}
MJC.Client.spawnedPeds = MJC.Client.spawnedPeds or {}
MJC.Client.spawnedBlips = MJC.Client.spawnedBlips or {}

local function loadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(25) end
    return HasModelLoaded(hash) and hash or nil
end

function MJC.Client.cleanupWorld()
    for _, ped in pairs(MJC.Client.spawnedPeds) do
        if DoesEntityExist(ped) then exports.ox_target:removeLocalEntity(ped); DeleteEntity(ped) end
    end
    for _, blip in pairs(MJC.Client.spawnedBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    MJC.Client.spawnedPeds = {}
    MJC.Client.spawnedBlips = {}
    if MJC.Client.clearBusinessZones then MJC.Client.clearBusinessZones() end
end

local function createBlip(npc)
    local data = npc.blip or {}
    if not data.enabled then return end
    local blip = AddBlipForCoord(tonumber(npc.x), tonumber(npc.y), tonumber(npc.z))
    SetBlipSprite(blip, tonumber(data.sprite) or 280)
    SetBlipColour(blip, tonumber(data.colour) or 0)
    SetBlipScale(blip, tonumber(data.scale) or 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label or npc.label)
    EndTextCommandSetBlipName(blip)
    MJC.Client.spawnedBlips[npc.id] = blip
end

local function spawnNpc(npc)
    if not MJC.Validation.isEnabled(npc.enabled) then return end
    local hash = loadModel(npc.model)
    if not hash then return print(('[missys_job_creator] Invalid NPC model %s for NPC %s'):format(npc.model, npc.id)) end
    local x, y, z = tonumber(npc.x), tonumber(npc.y), tonumber(npc.z)
    local ped = CreatePed(4, hash, x, y, z, tonumber(npc.heading) or 0.0, false, false)
    if ped == 0 then
        SetModelAsNoLongerNeeded(hash)
        print(('[missys_job_creator] CreatePed failed for NPC %s (%s) at %.3f %.3f %.3f'):format(npc.id, npc.model, x or 0.0, y or 0.0, z or 0.0))
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    if npc.scenario and npc.scenario ~= '' then TaskStartScenarioInPlace(ped, npc.scenario, 0, true) end

    MJC.Client.addNpcTarget(ped, npc)
    MJC.Client.spawnedPeds[npc.id] = ped
    createBlip(npc)
    SetModelAsNoLongerNeeded(hash)
end

function MJC.Client.refreshWorld()
    MJC.Client.cleanupWorld()
    for _, npc in pairs(MJC.Client.state.npcs or {}) do spawnNpc(npc) end
    if MJC.Client.createBusinessZones then MJC.Client.createBusinessZones() end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then MJC.Client.cleanupWorld(); SetNuiFocus(false, false); lib.hideTextUI() end
end)

CreateThread(function()
    Wait(2000)
    MJC.Client.refreshWorld()
end)
