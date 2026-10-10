MJC = MJC or {}
MJC.Client = MJC.Client or {}

-- Control names retained here for readability/documentation:
-- INPUT_MOVE_UP_ONLY / INPUT_MOVE_DOWN_ONLY / INPUT_MOVE_LEFT_ONLY / INPUT_MOVE_RIGHT_ONLY
-- INPUT_CELLPHONE_LEFT / INPUT_CELLPHONE_RIGHT / INPUT_FRONTEND_ACCEPT / INPUT_FRONTEND_CANCEL
local INPUT_MOVE_UP_ONLY = 32
local INPUT_MOVE_DOWN_ONLY = 33
local INPUT_MOVE_LEFT_ONLY = 34
local INPUT_MOVE_RIGHT_ONLY = 35
local INPUT_CELLPHONE_LEFT = 174
local INPUT_CELLPHONE_RIGHT = 175
local INPUT_FRONTEND_ACCEPT = 201
local INPUT_FRONTEND_CANCEL = 202
local INPUT_SPRINT = 21
local INPUT_COVER = 44
local INPUT_PICKUP = 38


local function normalizePresentationType(value)
    local presentationType = tostring(value or 'target'):lower()
    presentationType = presentationType:gsub('^%s+', ''):gsub('%s+$', '')
    if presentationType ~= 'target' and presentationType ~= 'marker' and presentationType ~= 'npc' and presentationType ~= 'prop' then
        MJC.Client.notify(('Unsupported point presentation: %s'):format(tostring(value)), 'error')
        return nil
    end
    return presentationType
end

local function loadModel(model)
    if type(model) ~= 'string' or model == '' then return nil end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

function MJC.Client.startPlacement(model, initial)
    if type(model) ~= 'string' or model == '' then model = Config.DefaultPedModel end
    local player = PlayerPedId()
    if IsPedInAnyVehicle(player, false) then
        MJC.Client.notify('Step out of the vehicle before placing an NPC.', 'error')
        return nil
    end

    local hash = loadModel(model or Config.DefaultPedModel)
    if not hash then MJC.Client.notify('That ped model is invalid.', 'error'); return nil end

    local start = GetEntityCoords(player)
    local front = GetOffsetFromEntityInWorldCoords(player, 0.0, 1.5, 0.0)
    local x = tonumber(initial and initial.x) or front.x
    local y = tonumber(initial and initial.y) or front.y
    local z = tonumber(initial and initial.z) or front.z
    local heading = tonumber(initial and initial.heading) or GetEntityHeading(player)
    local ped = CreatePed(4, hash, x, y, z, heading, false, false)
    if ped == 0 then
        SetModelAsNoLongerNeeded(hash)
        MJC.Client.notify('GTA could not create that ped. Try another model.', 'error')
        return nil
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 210, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    FreezeEntityPosition(player, true)
    lib.showTextUI('[WASD] Move  [Q/E] Height  [←/→] Rotate  [SHIFT] Faster  [ENTER] Confirm  [BACKSPACE] Cancel')
    local confirmed = false
    local cancelled = false

    while not confirmed and not cancelled do
        Wait(0)
        DisableControlAction(0, INPUT_FRONTEND_ACCEPT, true)
        DisableControlAction(0, INPUT_FRONTEND_CANCEL, true)
        local speed = Config.Placement.moveSpeed * (IsControlPressed(0, INPUT_SPRINT) and Config.Placement.fastMultiplier or 1.0)
        local rotation = GetGameplayCamRot(2).z
        local radians = math.rad(rotation)
        local forwardX, forwardY = -math.sin(radians), math.cos(radians)
        local rightX, rightY = math.cos(radians), math.sin(radians)

        if IsControlPressed(0, INPUT_MOVE_UP_ONLY) then x = x + forwardX * speed; y = y + forwardY * speed end
        if IsControlPressed(0, INPUT_MOVE_DOWN_ONLY) then x = x - forwardX * speed; y = y - forwardY * speed end
        if IsControlPressed(0, INPUT_MOVE_LEFT_ONLY) then x = x - rightX * speed; y = y - rightY * speed end
        if IsControlPressed(0, INPUT_MOVE_RIGHT_ONLY) then x = x + rightX * speed; y = y + rightY * speed end
        if IsControlPressed(0, INPUT_COVER) then z = z + Config.Placement.verticalSpeed end
        if IsControlPressed(0, INPUT_PICKUP) then z = z - Config.Placement.verticalSpeed end
        if IsControlPressed(0, INPUT_CELLPHONE_LEFT) then heading = heading + Config.Placement.rotationSpeed end
        if IsControlPressed(0, INPUT_CELLPHONE_RIGHT) then heading = heading - Config.Placement.rotationSpeed end

        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)

        if IsDisabledControlJustPressed(0, INPUT_FRONTEND_ACCEPT) then confirmed = true end
        if IsDisabledControlJustPressed(0, INPUT_FRONTEND_CANCEL) then cancelled = true end
    end

    lib.hideTextUI()
    FreezeEntityPosition(player, false)
    DeleteEntity(ped)
    SetModelAsNoLongerNeeded(hash)
    if cancelled then return nil end
    return { x = x, y = y, z = z, heading = heading }
end

function MJC.Client.startPointPlacement(presentationType, model, initial)
    presentationType = normalizePresentationType(presentationType)
    if not presentationType then return nil end
    if presentationType == 'npc' then
        if type(model) ~= 'string' or model == '' then model = Config.DefaultPedModel end
        return MJC.Client.startPlacement(model, initial)
    end
    if presentationType == 'prop' and (type(model) ~= 'string' or model == '') then model = Config.Points.defaultProp end
    local player=PlayerPedId()
    if IsPedInAnyVehicle(player,false) then MJC.Client.notify('Step out of the vehicle before placing a point.','error'); return nil end
    local front=GetOffsetFromEntityInWorldCoords(player,0.0,1.5,0.0)
    local x=tonumber(initial and initial.x) or front.x
    local y=tonumber(initial and initial.y) or front.y
    local z=tonumber(initial and initial.z) or front.z
    local heading=tonumber(initial and initial.heading) or GetEntityHeading(player)
    local preview=nil; local hash=nil
    if presentationType=='prop' then
        hash=loadModel(model or Config.Points.defaultProp)
        if not hash then MJC.Client.notify('That prop model is invalid.','error'); return nil end
        preview=CreateObject(hash,x,y,z,false,false,false)
        if preview==0 then SetModelAsNoLongerNeeded(hash); return nil end
        SetEntityAlpha(preview,190,false); SetEntityCollision(preview,false,false); FreezeEntityPosition(preview,true)
    end
    FreezeEntityPosition(player,true)
    lib.showTextUI('[WASD] Move  [Q/E] Height  [←/→] Rotate  [SHIFT] Faster  [ENTER] Confirm  [BACKSPACE] Cancel')
    local confirmed,cancelled=false,false
    while not confirmed and not cancelled do
        Wait(0)
        DisableControlAction(0,INPUT_FRONTEND_ACCEPT,true); DisableControlAction(0,INPUT_FRONTEND_CANCEL,true)
        local speed=Config.Placement.moveSpeed*(IsControlPressed(0,INPUT_SPRINT) and Config.Placement.fastMultiplier or 1.0)
        local radians=math.rad(GetGameplayCamRot(2).z); local fx,fy=-math.sin(radians),math.cos(radians); local rx,ry=math.cos(radians),math.sin(radians)
        if IsControlPressed(0,INPUT_MOVE_UP_ONLY) then x=x+fx*speed;y=y+fy*speed end
        if IsControlPressed(0,INPUT_MOVE_DOWN_ONLY) then x=x-fx*speed;y=y-fy*speed end
        if IsControlPressed(0,INPUT_MOVE_LEFT_ONLY) then x=x-rx*speed;y=y-ry*speed end
        if IsControlPressed(0,INPUT_MOVE_RIGHT_ONLY) then x=x+rx*speed;y=y+ry*speed end
        if IsControlPressed(0,INPUT_COVER) then z=z+Config.Placement.verticalSpeed end
        if IsControlPressed(0,INPUT_PICKUP) then z=z-Config.Placement.verticalSpeed end
        if IsControlPressed(0,INPUT_CELLPHONE_LEFT) then heading=heading+Config.Placement.rotationSpeed end
        if IsControlPressed(0,INPUT_CELLPHONE_RIGHT) then heading=heading-Config.Placement.rotationSpeed end
        if preview and DoesEntityExist(preview) then SetEntityCoordsNoOffset(preview,x,y,z,false,false,false);SetEntityHeading(preview,heading)
        else DrawMarker(2,x,y,z+0.15,0.0,0.0,0.0,0.0,180.0,0.0,0.28,0.28,0.28,235,160,196,210,false,true,2,false,nil,nil,false) end
        if IsDisabledControlJustPressed(0,INPUT_FRONTEND_ACCEPT) then confirmed=true end
        if IsDisabledControlJustPressed(0,INPUT_FRONTEND_CANCEL) then cancelled=true end
    end
    lib.hideTextUI(); FreezeEntityPosition(player,false)
    if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
    if hash then SetModelAsNoLongerNeeded(hash) end
    if cancelled then return nil end
    return {x=x,y=y,z=z,heading=heading}
end
