MJC = MJC or {}
MJC.Jobs = {}

local J = MJC.Jobs

local function runtimeDefinition(job, grades)
    local definition = {
        label = job.label,
        defaultDuty = job.default_duty == true or job.default_duty == 1,
        offDutyPay = job.off_duty_pay == true or job.off_duty_pay == 1,
        grades = {},
    }
    if job.job_type and job.job_type ~= '' then definition.type = job.job_type end
    for i = 1, #grades do
        local grade = grades[i]
        definition.grades[tonumber(grade.grade_level or grade.level)] = {
            name = grade.name,
            payment = tonumber(grade.payment) or 0,
            isboss = grade.is_boss == 1 or grade.isboss == true,
            bankAuth = grade.bank_auth == 1 or grade.bankAuth == true or grade.is_boss == 1 or grade.isboss == true,
        }
    end
    return definition
end

function J.restore()
    local restored = 0
    for _, job in pairs(MJC.State.jobs) do
        if MJC.Validation.isEnabled(job.enabled) then
            local success, message = exports.qbx_core:CreateJob(job.job_name, runtimeDefinition(job, job.grades))
            if success then
                restored = restored + 1
            else
                print(('[missys_job_creator] Failed to restore job %s: %s'):format(job.job_name, message or 'unknown'))
            end
        end
    end
    return restored
end

local function assignedMemberCount(jobName)
    local ok, members = pcall(function()
        return exports.qbx_core:GetGroupMembers(jobName, 'job')
    end)
    if not ok or type(members) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(members) do count = count + 1 end
    return count
end

function J.dependenciesForJob(jobName)
    local dependencies = {}
    local businessCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_businesses WHERE job_name = ?', { jobName })) or 0
    local shopCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_shops WHERE business_job = ?', { jobName })) or 0
    local npcCount = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM missys_job_creator_npcs WHERE role_type = 'hire' AND role_ref = ?", { jobName })) or 0
    local pointCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_points WHERE job_name = ?', { jobName })) or 0
    local blipCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_blips WHERE job_name = ?', { jobName })) or 0
    local fleetCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_fleet WHERE job_name = ?', { jobName })) or 0
    local memberCount = assignedMemberCount(jobName)
    if businessCount > 0 then dependencies[#dependencies + 1] = ('%s business link(s)'):format(businessCount) end
    if shopCount > 0 then dependencies[#dependencies + 1] = ('%s shop link(s)'):format(shopCount) end
    if npcCount > 0 then dependencies[#dependencies + 1] = ('%s hiring NPC link(s)'):format(npcCount) end
    if pointCount > 0 then dependencies[#dependencies + 1] = ('%s world point(s)'):format(pointCount) end
    if blipCount > 0 then dependencies[#dependencies + 1] = ('%s job blip(s)'):format(blipCount) end
    if fleetCount > 0 then dependencies[#dependencies + 1] = ('%s fleet vehicle(s)'):format(fleetCount) end
    if memberCount > 0 then dependencies[#dependencies + 1] = ('%s assigned member(s)'):format(memberCount) end
    return dependencies
end

function J.save(payload)
    local jobName, jobNameError = MJC.Validation.jobName(payload.job_name)
    if not jobName then return false, jobNameError end
    local label, labelError = MJC.Validation.label(payload.label, 'Job label')
    if not label then return false, labelError end
    local grades, gradesError = MJC.Validation.grades(payload.grades)
    if not grades then return false, gradesError end

    local id = tonumber(payload.id)
    if id then
        local current = MJC.State.jobs[id]
        if not current then return false, 'That creator job no longer exists.' end
        if current.job_name ~= jobName then return false, 'The internal job name cannot be changed after creation. Duplicate the job instead.' end
    else
        if exports.qbx_core:GetJob(jobName) or MJC.Persistence.findJobByName(jobName) then
            return false, ('Job "%s" already exists.'):format(jobName)
        end
    end

    local settings = type(payload.settings) == 'table' and payload.settings or {}
    local enabled = payload.enabled == false and 0 or 1
    if id and enabled == 0 and assignedMemberCount(jobName) > 0 then
        return false, 'Move assigned members off this job before disabling it.'
    end
    if id then
        MySQL.update.await([[
            UPDATE missys_job_creator_jobs
            SET label = ?, job_type = ?, default_duty = ?, off_duty_pay = ?, enabled = ?, settings_json = ?
            WHERE id = ?
        ]], { label, MJC.Validation.trim(payload.job_type), payload.default_duty == false and 0 or 1, payload.off_duty_pay == true and 1 or 0, enabled, json.encode(settings), id })
    else
        id = MySQL.insert.await([[
            INSERT INTO missys_job_creator_jobs (job_name, label, job_type, default_duty, off_duty_pay, enabled, settings_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], { jobName, label, MJC.Validation.trim(payload.job_type), payload.default_duty == false and 0 or 1, payload.off_duty_pay == true and 1 or 0, enabled, json.encode(settings) })
    end

    MySQL.query.await('DELETE FROM missys_job_creator_grades WHERE job_id = ?', { id })
    for i = 1, #grades do
        local grade = grades[i]
        MySQL.insert.await([[
            INSERT INTO missys_job_creator_grades (job_id, grade_level, name, payment, is_boss, bank_auth)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], { id, grade.level, grade.name, grade.payment, grade.isboss and 1 or 0, grade.bankAuth and 1 or 0 })
    end

    local dbJob = {
        job_name = jobName,
        label = label,
        job_type = MJC.Validation.trim(payload.job_type),
        default_duty = payload.default_duty == false and 0 or 1,
        off_duty_pay = payload.off_duty_pay == true and 1 or 0,
        settings = settings,
    }
    local dbGrades = {}
    for i = 1, #grades do
        dbGrades[i] = {
            grade_level = grades[i].level,
            name = grades[i].name,
            payment = grades[i].payment,
            is_boss = grades[i].isboss and 1 or 0,
            bank_auth = grades[i].bankAuth and 1 or 0,
        }
    end

    if enabled == 1 then
        local success, message = exports.qbx_core:CreateJob(jobName, runtimeDefinition(dbJob, dbGrades))
        if not success then return false, ('Saved, but QBX rejected the runtime job: %s'):format(message or 'unknown') end
    else
        pcall(function() exports.qbx_core:RemoveJob(jobName) end)
    end
    return true, id
end

function J.delete(id)
    id = tonumber(id)
    local job = id and MJC.State.jobs[id]
    if not job then return false, 'Job not found.' end
    local dependencies = J.dependenciesForJob(job.job_name)
    if #dependencies > 0 then
        return false, 'Remove or reassign these first: ' .. table.concat(dependencies, ', ')
    end
    exports.qbx_core:RemoveJob(job.job_name)
    MySQL.query.await('DELETE FROM missys_job_creator_jobs WHERE id = ?', { id })
    return true
end
