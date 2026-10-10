MJC = MJC or {}
MJC.Client = MJC.Client or {}

MJC.Client.pointRuntime = MJC.Client.pointRuntime or { zones={}, entities={}, pointBlips={} }
local R = MJC.Client.pointRuntime
local pointBlips = R.pointBlips

local function clearZone(id)
    if R.zones[id] then
        pcall(function() exports.ox_target:removeZone(R.zones[id]) end)
        R.zones[id] = nil
    end
end

local function clearEntity(id)
    local entity = R.entities[id]
    if entity and DoesEntityExist(entity) then
        pcall(function() exports.ox_target:removeLocalEntity(entity) end)
        DeleteEntity(entity)
    end
    R.entities[id] = nil
end

function MJC.Client.clearPoints()
    for id in pairs(R.zones) do clearZone(id) end
    for id in pairs(R.entities) do clearEntity(id) end
    for id,handle in pairs(pointBlips) do if DoesBlipExist(handle) then RemoveBlip(handle) end; pointBlips[id]=nil end
end

local function pointCoords(point)
    return vector3(tonumber(point.x) or 0.0, tonumber(point.y) or 0.0, tonumber(point.z) or 0.0)
end

local function targetOption(point)
    return {
        name=('mjc_point_%s'):format(point.id),
        label=((point.presentation or {}).interactionText or point.label or 'Interact'),
        icon=((point.presentation or {}).icon or 'fa-solid fa-hand-pointer'),
        distance=tonumber(point.radius) or 2.0,
        onSelect=function() MJC.Client.usePoint(point) end,
    }
end

local function loadModel(model)
    local hash=joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function spawnPointEntity(point)
    local presentation=point.presentation or {}
    local model = presentation.model
    if type(model) ~= 'string' or model == '' then
        model = point.presentation_type=='npc' and Config.DefaultPedModel or Config.Points.defaultProp
    end
    local hash=loadModel(model)
    if not hash then return end
    local entity
    if point.presentation_type=='npc' then
        entity=CreatePed(4,hash,point.x,point.y,point.z,point.heading or 0.0,false,false)
        if entity and entity~=0 then
            SetEntityInvincible(entity,true); SetBlockingOfNonTemporaryEvents(entity,true)
            local scenario=presentation.scenario or Config.DefaultScenario
            if scenario and scenario~='' then TaskStartScenarioInPlace(entity,scenario,0,true) end
        end
    else
        entity=CreateObject(hash,point.x,point.y,point.z,false,false,false)
        if entity and entity~=0 then SetEntityHeading(entity,point.heading or 0.0) end
    end
    if not entity or entity==0 then SetModelAsNoLongerNeeded(hash); return end
    SetEntityAsMissionEntity(entity,true,true); FreezeEntityPosition(entity,true)
    R.entities[point.id]=entity
    exports.ox_target:addLocalEntity(entity,{targetOption(point)})
    SetModelAsNoLongerNeeded(hash)
end

local function ensurePointBlip(point)
    local cfg=point.blip or {}
    if cfg.enabled~=true then return end
    local access=point.access or {}
    if access.mode~='public' and not exports.qbx_core:HasGroup({[point.job_name]=tonumber(access.minGrade) or 0}) then return end
    if pointBlips[point.id] and DoesBlipExist(pointBlips[point.id]) then return end
    local handle=AddBlipForCoord(tonumber(point.x),tonumber(point.y),tonumber(point.z))
    SetBlipSprite(handle,tonumber(cfg.sprite) or 280); SetBlipColour(handle,tonumber(cfg.colour or cfg.color) or 0); SetBlipScale(handle,tonumber(cfg.scale) or 0.65); SetBlipAsShortRange(handle,cfg.shortRange~=false)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(cfg.label or point.label or point.job_name); EndTextCommandSetBlipName(handle)
    pointBlips[point.id]=handle
end

local function ensurePoint(point, distance)
    if not MJC.Validation.isEnabled(point.enabled) then clearZone(point.id); clearEntity(point.id); return end
    if point.presentation_type=='target' and not R.zones[point.id] then
        R.zones[point.id]=exports.ox_target:addSphereZone({coords=pointCoords(point),radius=tonumber(point.radius) or 1.5,debug=Config.Debug,options={targetOption(point)}})
    elseif (point.presentation_type=='npc' or point.presentation_type=='prop') and distance <= Config.Points.streamDistance and not R.entities[point.id] then
        spawnPointEntity(point)
    elseif (point.presentation_type=='npc' or point.presentation_type=='prop') and distance > Config.Points.streamDistance+20 then
        clearEntity(point.id)
    end
end

function MJC.Client.refreshPoints()
    -- Target zones are cheap; streamed entities are rebuilt lazily by the thread.
    local present={}
    local player=PlayerPedId(); local coords=GetEntityCoords(player)
    for _,point in pairs((MJC.Client.state or {}).points or {}) do
        present[point.id]=true
        ensurePoint(point,#(coords-pointCoords(point)))
        ensurePointBlip(point)
    end
    for id in pairs(R.zones) do if not present[id] then clearZone(id) end end
    for id in pairs(R.entities) do if not present[id] then clearEntity(id) end end
    for id,handle in pairs(pointBlips) do if not present[id] then if DoesBlipExist(handle) then RemoveBlip(handle) end; pointBlips[id]=nil end end
end

CreateThread(function()
    while true do
        Wait(1500)
        if MJC.Client.state and MJC.Client.state.points then MJC.Client.refreshPoints() end
    end
end)

CreateThread(function()
    while true do
        local wait=1000
        local ped=PlayerPedId(); local coords=GetEntityCoords(ped)
        for _,point in pairs((MJC.Client.state or {}).points or {}) do
            if MJC.Validation.isEnabled(point.enabled) and point.presentation_type=='marker' then
                local dist=#(coords-pointCoords(point))
                if dist < Config.Points.markerDrawDistance then
                    wait=0
                    local presentation=point.presentation or {}
                    DrawMarker(tonumber(presentation.markerType) or 2,point.x,point.y,point.z+0.15,0.0,0.0,0.0,0.0,180.0,0.0,0.22,0.22,0.22,235,160,196,180,false,true,2,false,nil,nil,false)
                    if dist <= (tonumber(point.radius) or 2.0) then
                        lib.showTextUI(('[E] %s'):format(point.label or 'Interact'))
                        if IsControlJustReleased(0,38) then MJC.Client.usePoint(point) end
                    end
                end
            end
        end
        if wait~=0 then lib.hideTextUI() end
        Wait(wait)
    end
end)
