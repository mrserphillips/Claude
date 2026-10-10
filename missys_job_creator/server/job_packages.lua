MJC=MJC or {}; MJC.JobPackages=MJC.JobPackages or {}
local P=MJC.JobPackages
local PACKAGE_VERSION=MJC.Constants.PackageVersion or 2

local function creatorJob(idOrName)
    local id=tonumber(idOrName)
    if id and MJC.State.jobs[id] then return MJC.State.jobs[id] end
    return MJC.Persistence.findJobByName(tostring(idOrName or ''))
end

local function cleanGrade(g)
    return {level=tonumber(g.grade_level or g.level) or 0,name=g.name,payment=tonumber(g.payment) or 0,isboss=MJC.Validation.isEnabled(g.is_boss) or g.isboss==true,bankAuth=MJC.Validation.isEnabled(g.bank_auth) or g.bankAuth==true}
end
local function cleanPoint(row)
    return {label=row.label,job_name=row.job_name,point_type=row.point_type,presentation_type=row.presentation_type,x=row.x,y=row.y,z=row.z,heading=row.heading,radius=row.radius,access=row.access,presentation=row.presentation,config=row.config,blip=row.blip,hours=row.hours,enabled=MJC.Validation.isEnabled(row.enabled)}
end
local function cleanBlip(row)
    return {job_name=row.job_name,label=row.label,x=row.x,y=row.y,z=row.z,sprite=row.sprite,colour=row.colour,scale=row.scale,short_range=MJC.Validation.isEnabled(row.short_range),access=row.access,enabled=MJC.Validation.isEnabled(row.enabled)}
end
local function cleanFleet(row)
    return {job_name=row.job_name,model=row.model,label=row.label,min_grade=row.min_grade,plate_prefix=row.plate_prefix,enabled=MJC.Validation.isEnabled(row.enabled)}
end

function P.export(idOrName)
    local job=creatorJob(idOrName); if not job then return false,'Creator-owned job not found.' end
    local package={packageVersion=PACKAGE_VERSION,kind='missys_job_creator_job',job={job_name=job.job_name,label=job.label,job_type=job.job_type,default_duty=MJC.Validation.isEnabled(job.default_duty),off_duty_pay=MJC.Validation.isEnabled(job.off_duty_pay),enabled=MJC.Validation.isEnabled(job.enabled),settings=job.settings or {},grades={}},points={},blips={},fleet={}}
    for _,g in ipairs(job.grades or {}) do package.job.grades[#package.job.grades+1]=cleanGrade(g) end
    for _,row in ipairs(MJC.Persistence.pointsForJob(job.job_name)) do package.points[#package.points+1]=cleanPoint(row) end
    for _,row in ipairs(MJC.Persistence.blipsForJob(job.job_name)) do package.blips[#package.blips+1]=cleanBlip(row) end
    for _,row in ipairs(MJC.Persistence.fleetForJob(job.job_name)) do package.fleet[#package.fleet+1]=cleanFleet(row) end
    local encoded=json.encode(package)
    if #encoded>(Config.Packages.maxBytes or 512000) then return false,'Job package is too large to export.' end
    return true,encoded
end

local function decodePackage(raw)
    if type(raw)=='table' then return raw end
    if type(raw)~='string' or raw=='' then return nil,'Paste a job package first.' end
    if #raw>(Config.Packages.maxBytes or 512000) then return nil,'Job package exceeds the size limit.' end
    local ok,data=pcall(json.decode,raw); if not ok or type(data)~='table' then return nil,'Job package JSON is invalid.' end
    if tonumber(data.packageVersion)~=PACKAGE_VERSION or data.kind~='missys_job_creator_job' then return nil,'Unsupported job package version.' end
    if type(data.job)~='table' then return nil,'Job package is missing its job definition.' end
    return data
end

local function copyPackage(data,newName,newLabel)
    local jobData=data.job
    local targetName,err=MJC.Validation.jobName(newName or jobData.job_name); if not targetName then return false,err end
    if exports.qbx_core:GetJob(targetName) or MJC.Persistence.findJobByName(targetName) then return false,('Job "%s" already exists.'):format(targetName) end
    local label,lerr=MJC.Validation.label(newLabel or jobData.label,'Job label'); if not label then return false,lerr end
    local save={job_name=targetName,label=label,job_type=jobData.job_type,default_duty=jobData.default_duty,off_duty_pay=jobData.off_duty_pay,enabled=jobData.enabled~=false,settings=jobData.settings or {},grades=jobData.grades}
    local ok,newId=MJC.Jobs.save(save); if not ok then return false,newId end
    for _,row in ipairs(data.points or {}) do local c={};for k,v in pairs(row) do c[k]=v end;c.job_name=targetName;c.id=nil;local pok,perr=MJC.Points.save(c);if not pok then return false,('Job created but point import failed: %s'):format(perr) end end
    for _,row in ipairs(data.blips or {}) do local c={};for k,v in pairs(row) do c[k]=v end;c.job_name=targetName;c.id=nil;local bok,berr=MJC.Blips.save(c);if not bok then return false,('Job created but blip import failed: %s'):format(berr) end end
    for _,row in ipairs(data.fleet or {}) do local c={};for k,v in pairs(row) do c[k]=v end;c.job_name=targetName;c.id=nil;local fok,ferr=MJC.Fleet.save(c);if not fok then return false,('Job created but fleet import failed: %s'):format(ferr) end end
    return true,newId
end

function P.duplicate(idOrName,newName,newLabel)
    local ok,raw=P.export(idOrName); if not ok then return false,raw end
    local data,err=decodePackage(raw); if not data then return false,err end
    return copyPackage(data,newName,newLabel)
end

function P.import(raw,newName,newLabel)
    local data,err=decodePackage(raw); if not data then return false,err end
    return copyPackage(data,newName,newLabel)
end

function P.preview(raw)
    local data,err=decodePackage(raw); if not data then return false,err end
    local conflict=exports.qbx_core:GetJob(data.job.job_name)~=nil or MJC.Persistence.findJobByName(data.job.job_name)~=nil
    return true,{packageVersion=data.packageVersion,job_name=data.job.job_name,label=data.job.label,grades=#(data.job.grades or {}),points=#(data.points or {}),blips=#(data.blips or {}),fleet=#(data.fleet or {}),conflict=conflict}
end
