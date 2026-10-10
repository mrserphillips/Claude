MJC=MJC or {}; MJC.Fleet=MJC.Fleet or {}
local F=MJC.Fleet
local activeLeases={}; F.activeLeases=activeLeases

local function gradeLevel(job)
    if type(job)~='table' then return 0 end
    if type(job.grade)=='table' then return tonumber(job.grade.level or job.grade.grade) or 0 end
    return tonumber(job.grade) or 0
end

local function normalize(payload)
    if type(payload)~='table' then return nil,'Invalid fleet entry.' end
    local job,err=MJC.Validation.jobName(payload.job_name); if not job then return nil,err end
    if not exports.qbx_core:GetJob(job) then return nil,'The linked QBX job does not exist.' end
    local model=MJC.Validation.trim(payload.model):lower(); if model=='' or #model>64 then return nil,'Vehicle model is required.' end
    local label,lerr=MJC.Validation.label(payload.label or model,'Vehicle label'); if not label then return nil,lerr end
    local prefix=MJC.Validation.trim(payload.plate_prefix or payload.platePrefix):upper():gsub('[^A-Z0-9]',''):sub(1,6)
    return {id=tonumber(payload.id),job_name=job,model=model,label=label,min_grade=math.max(0,math.floor(tonumber(payload.min_grade or payload.minGrade) or 0)),plate_prefix=prefix,enabled=payload.enabled~=false}
end

function F.save(payload)
    local row,err=normalize(payload); if not row then return false,err end
    if row.id and not MJC.State.fleet[row.id] then return false,'Fleet entry not found.' end
    local params={row.job_name,row.model,row.label,row.min_grade,row.plate_prefix,row.enabled and 1 or 0}
    if row.id then params[#params+1]=row.id; MySQL.update.await('UPDATE missys_job_creator_fleet SET job_name=?,model=?,label=?,min_grade=?,plate_prefix=?,enabled=? WHERE id=?',params); return true,row.id end
    local id=MySQL.insert.await('INSERT INTO missys_job_creator_fleet (job_name,model,label,min_grade,plate_prefix,enabled) VALUES (?,?,?,?,?,?)',params); return true,id
end

function F.delete(id)
    id=tonumber(id); if not id or not MJC.State.fleet[id] then return false,'Fleet entry not found.' end
    for _,lease in pairs(activeLeases) do if tonumber(lease.fleetId)==id then return false,'That fleet vehicle currently has an active lease.' end end
    MySQL.query.await('DELETE FROM missys_job_creator_fleet WHERE id=?',{id}); return true
end

local function allowedAtPoint(point,fleetId)
    local list=(point.config or {}).allowedFleet or (point.config or {}).allowed_fleet
    if type(list)~='table' or #list==0 then return true end
    for _,id in ipairs(list) do if tonumber(id)==tonumber(fleetId) then return true end end
    return false
end

function F.requestLease(source,pointId,fleetId)
    if activeLeases[source] then return false,'Return your current fleet vehicle first.' end
    local point=MJC.Persistence.findPoint(pointId); if not point or point.point_type~='garage' then return false,'Garage point not found.' end
    local ok,player=MJC.Points.canUse(source,point,Config.Points.serverDistance); if not ok then return false,player end
    local entry=MJC.State.fleet[tonumber(fleetId)]
    if not entry or not MJC.Validation.isEnabled(entry.enabled) or entry.job_name~=point.job_name then return false,'Fleet vehicle unavailable.' end
    if not allowedAtPoint(point,entry.id) then return false,'That vehicle is not available at this garage.' end
    if gradeLevel(player.PlayerData.job)<(tonumber(entry.min_grade) or 0) then return false,'Your grade cannot use that vehicle.' end
    local spawn=(point.config or {}).spawn or {}
    if not tonumber(spawn.x) then
        local heading=math.rad(tonumber(point.heading) or 0); spawn={x=point.x-math.sin(heading)*4.0,y=point.y+math.cos(heading)*4.0,z=point.z,heading=point.heading}
    end
    local lease={fleetId=entry.id,pointId=point.id,job=point.job_name,netId=nil,created=os.time()}; activeLeases[source]=lease
    return true,{model=entry.model,label=entry.label,platePrefix=entry.plate_prefix or '',spawn=spawn,fleetId=entry.id}
end

function F.registerVehicle(source,netId)
    local lease=activeLeases[source]; if not lease then return false,'No active fleet lease.' end
    netId=tonumber(netId); if not netId or netId<=0 then activeLeases[source]=nil; return false,'Invalid vehicle network id.' end
    lease.netId=netId; return true
end

function F.releaseLease(source,pointId)
    local lease=activeLeases[source]; if not lease then return false,'You do not have a fleet vehicle out.' end
    local point=MJC.Persistence.findPoint(pointId or lease.pointId)
    if point then
        local ok,err=MJC.Points.canUse(source,point,(tonumber(point.radius) or 2.0)+8.0); if not ok then return false,err end
    end
    activeLeases[source]=nil; return true,{netId=lease.netId}
end

AddEventHandler('playerDropped',function()
    local lease=activeLeases[source]
    if lease and lease.netId then local entity=NetworkGetEntityFromNetworkId(lease.netId); if entity and entity~=0 and DoesEntityExist(entity) then DeleteEntity(entity) end end
    activeLeases[source]=nil
end)
