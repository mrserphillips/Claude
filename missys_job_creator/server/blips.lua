MJC = MJC or {}
MJC.Blips = MJC.Blips or {}
local B = MJC.Blips

local function normalize(payload)
    if type(payload)~='table' then return nil,'Invalid blip.' end
    local job,err=MJC.Validation.jobName(payload.job_name); if not job then return nil,err end
    if not exports.qbx_core:GetJob(job) then return nil,'The linked QBX job does not exist.' end
    local label,lerr=MJC.Validation.label(payload.label,'Blip label'); if not label then return nil,lerr end
    local pos=type(payload.position)=='table' and payload.position or payload
    local x,y,z=tonumber(pos.x),tonumber(pos.y),tonumber(pos.z); if not x or not y or not z then return nil,'Set blip coordinates first.' end
    local access=type(payload.access)=='table' and payload.access or {}
    local mode=access.mode; if mode~='job' and mode~='grade' then mode='public' end
    return {
        id=tonumber(payload.id),job_name=job,label=label,x=x,y=y,z=z,
        sprite=math.max(1,math.floor(tonumber(payload.sprite) or 280)),
        colour=math.max(0,math.floor(tonumber(payload.colour or payload.color) or 0)),
        scale=math.max(0.2,math.min(3.0,tonumber(payload.scale) or 0.8)),
        short_range=payload.short_range~=false,
        access={mode=mode,minGrade=math.max(0,math.floor(tonumber(access.minGrade) or 0))},
        enabled=payload.enabled~=false,
    }
end

function B.save(payload)
    local b,err=normalize(payload); if not b then return false,err end
    if b.id and not MJC.State.blips[b.id] then return false,'Blip not found.' end
    local params={b.job_name,b.label,b.x,b.y,b.z,b.sprite,b.colour,b.scale,b.short_range and 1 or 0,json.encode(b.access),b.enabled and 1 or 0}
    if b.id then
        params[#params+1]=b.id
        MySQL.update.await('UPDATE missys_job_creator_blips SET job_name=?,label=?,x=?,y=?,z=?,sprite=?,colour=?,scale=?,short_range=?,access_json=?,enabled=? WHERE id=?',params)
        return true,b.id
    end
    local id=MySQL.insert.await('INSERT INTO missys_job_creator_blips (job_name,label,x,y,z,sprite,colour,scale,short_range,access_json,enabled) VALUES (?,?,?,?,?,?,?,?,?,?,?)',params)
    return true,id
end

function B.delete(id)
    id=tonumber(id); if not id or not MJC.State.blips[id] then return false,'Blip not found.' end
    MySQL.query.await('DELETE FROM missys_job_creator_blips WHERE id=?',{id}); return true
end
