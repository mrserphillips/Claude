MJC=MJC or {}; MJC.Client=MJC.Client or {}; MJC.Client.fleetVehicle=nil; MJC.Client.fleetPoint=nil

local function loadVehicle(model)
    local hash=joaat(model); if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash); local timeout=GetGameTimer()+7000
    while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function doReturn(point)
    if not MJC.Client.fleetVehicle or not DoesEntityExist(MJC.Client.fleetVehicle) then
        local response=lib.callback.await('missys_job_creator:server:returnFleet',false,point.id); if response and response.ok then MJC.Client.fleetVehicle=nil;MJC.Client.fleetPoint=nil end
        return
    end
    local response=lib.callback.await('missys_job_creator:server:returnFleet',false,point.id)
    if not response or not response.ok then return MJC.Client.notify(response and response.error or 'Could not return fleet vehicle.','error') end
    DeleteEntity(MJC.Client.fleetVehicle); MJC.Client.fleetVehicle=nil;MJC.Client.fleetPoint=nil; MJC.Client.notify('Fleet vehicle returned.','success')
end

local function spawnFleet(point,entry)
    local response=lib.callback.await('missys_job_creator:server:requestFleet',false,point.id,entry.id)
    if not response or not response.ok then return MJC.Client.notify(response and response.error or 'Fleet vehicle unavailable.','error') end
    local data=response.data; local hash=loadVehicle(data.model)
    if not hash then MJC.Client.notify('That vehicle model could not be loaded.','error'); lib.callback.await('missys_job_creator:server:returnFleet',false,point.id); return end
    local s=data.spawn; local veh=CreateVehicle(hash,s.x,s.y,s.z,s.heading or 0.0,true,false); SetModelAsNoLongerNeeded(hash)
    if veh==0 then lib.callback.await('missys_job_creator:server:returnFleet',false,point.id); return MJC.Client.notify('Could not spawn the fleet vehicle.','error') end
    local prefix=(data.platePrefix or 'JOB'):sub(1,6); local plate=('%s%02d'):format(prefix,math.random(10,99)):sub(1,8)
    SetVehicleNumberPlateText(veh,plate); SetEntityAsMissionEntity(veh,true,true); SetVehicleEngineOn(veh,true,true,false); SetVehicleDoorsLocked(veh,1)
    local ped=PlayerPedId(); SetPedIntoVehicle(ped,veh,-1)
    local netId=NetworkGetNetworkIdFromEntity(veh); SetNetworkIdCanMigrate(netId,true)
    local registered=lib.callback.await('missys_job_creator:server:registerFleetVehicle',false,netId)
    if not registered or not registered.ok then DeleteEntity(veh); return MJC.Client.notify('Fleet lease could not be registered.','error') end
    MJC.Client.fleetVehicle=veh; MJC.Client.fleetPoint=point.id
    if GetResourceState('qbx_vehiclekeys')=='started' then TriggerEvent('vehiclekeys:client:SetOwner',plate) end
end

function MJC.Client.openFleet(point)
    local options={}
    if MJC.Client.fleetVehicle then options[#options+1]={title='Return current fleet vehicle',icon='rotate-left',onSelect=function() doReturn(point) end} end
    local allowed=(point.config or {}).allowedFleet or (point.config or {}).allowed_fleet
    local allowedMap=nil
    if type(allowed)=='table' and #allowed>0 then allowedMap={}; for _,id in ipairs(allowed) do allowedMap[tonumber(id)]=true end end
    for _,entry in pairs((MJC.Client.state or {}).fleet or {}) do
        if entry.job_name==point.job_name and MJC.Validation.isEnabled(entry.enabled) and (not allowedMap or allowedMap[tonumber(entry.id)]) then
            local current=entry
            options[#options+1]={title=current.label or current.model,description=('Minimum grade %s'):format(current.min_grade or 0),icon='car',onSelect=function() spawnFleet(point,current) end}
        end
    end
    if #options==0 then options={{title='No fleet vehicles configured',disabled=true}} end
    lib.registerContext({id=('mjc_fleet_%s'):format(point.id),title=point.label or 'Job Fleet',options=options}); lib.showContext(('mjc_fleet_%s'):format(point.id))
end

RegisterNUICallback('returnFleet',function(data,cb)
    local point=MJC.Client.state.points and MJC.Client.state.points[tonumber(data.pointId)]
    if point then doReturn(point); cb({ok=true}) else cb({ok=false}) end
end)
