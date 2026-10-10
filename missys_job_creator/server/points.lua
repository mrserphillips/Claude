MJC = MJC or {}
MJC.Points = MJC.Points or {}

local P = MJC.Points

local function currentGrade(job)
    if type(job) ~= 'table' then return 0 end
    if type(job.grade) == 'table' then return tonumber(job.grade.level or job.grade.grade) or 0 end
    return tonumber(job.grade) or 0
end

local function isOnDuty(job)
    if type(job) ~= 'table' then return false end
    return job.onduty == true or job.onDuty == true
end

function P.isOpen(point)
    local hours = point and (point.hours or MJC.Validation.decode(point.hours_json, { enabled = false })) or { enabled = false }
    if not hours.enabled then return true end
    local hour = tonumber(os.date('*t').hour) or 0
    local startHour = tonumber(hours.start) or 0
    local finishHour = tonumber(hours.finish) or 23
    if startHour == finishHour then return true end
    if startHour < finishHour then return hour >= startHour and hour < finishHour end
    return hour >= startHour or hour < finishHour
end

function P.save(payload)
    local point, pointError = MJC.Validation.point(payload)
    if not point then return false, pointError end
    if point.job_name ~= '' and not exports.qbx_core:GetJob(point.job_name) then return false, 'The linked QBX job does not exist.' end

    if point.point_type == 'shop' or point.point_type == 'sell' then
        local paymentType = MJC.Validation.trim(point.config.paymentType or Config.DefaultPaymentType)
        if not MJC.Constants.PaymentTypes[paymentType] then return false, 'Invalid payment type.' end
        point.config.paymentType = paymentType
        if point.config.paymentType == 'black_money' and not exports.ox_inventory:Items('black_money') then
            return false, 'ox_inventory item "black_money" does not exist.'
        end

        if point.point_type == 'shop' then
            local businessJob = MJC.Validation.trim(point.config.businessJob):lower()
            if businessJob == '' and point.job_name ~= '' then businessJob = point.job_name end
            local needsBusiness = point.config.stockMode == 'business' or point.config.revenueMode == 'business'
            if needsBusiness and businessJob == '' then
                return false, 'Choose a business / society link for business stock or society revenue.'
            end
            if businessJob ~= '' then
                local normalized, businessError = MJC.Validation.jobName(businessJob)
                if not normalized then return false, businessError end
                if not exports.qbx_core:GetJob(normalized) then return false, 'The linked business QBX job does not exist.' end
                point.config.businessJob = normalized
                if point.config.stockMode == 'business' and MJC.Businesses and MJC.Businesses.ensureLink then
                    local linked, linkError = MJC.Businesses.ensureLink(normalized)
                    if not linked then return false, linkError or 'Could not create the business stock link.' end
                end
            else
                point.config.businessJob = ''
            end
        end
    end

    local id = point.id
    if id and not MJC.Persistence.findPoint(id) then return false, 'That world point no longer exists.' end
    local enabled = point.enabled and 1 or 0
    local params = {
        point.job_name, point.label, point.point_type, point.presentation_type,
        point.x, point.y, point.z, point.heading, point.radius,
        json.encode(point.access), json.encode(point.presentation), json.encode(point.config),
        json.encode(point.blip), json.encode(point.hours), enabled,
    }

    if id then
        params[#params + 1] = id
        MySQL.update.await([[
            UPDATE missys_job_creator_points
            SET job_name=?, label=?, point_type=?, presentation_type=?, x=?, y=?, z=?, heading=?, radius=?,
                access_json=?, presentation_json=?, config_json=?, blip_json=?, hours_json=?, enabled=?
            WHERE id=?
        ]], params)
    else
        id = MySQL.insert.await([[
            INSERT INTO missys_job_creator_points
            (job_name,label,point_type,presentation_type,x,y,z,heading,radius,access_json,presentation_json,config_json,blip_json,hours_json,enabled)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ]], params)
    end
    return true, id
end

function P.delete(id)
    id = tonumber(id)
    if not id or not MJC.Persistence.findPoint(id) then return false, 'World point not found.' end
    MySQL.query.await('DELETE FROM missys_job_creator_points WHERE id = ?', { id })
    return true
end

function P.dependenciesForJob(jobName)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_points WHERE job_name = ?', { jobName })) or 0
end

function P.canUse(source, point, maxDistance)
    if not point or not MJC.Validation.isEnabled(point.enabled) then return false, 'This point is disabled.' end
    if not P.isOpen(point) then return false, 'This point is currently closed.' end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData then return false, 'Player unavailable.' end
    local job = player.PlayerData.job or {}
    local access = point.access or MJC.Validation.decode(point.access_json, { mode = 'job', minGrade = 0, allowedGrades = {}, duty = 'any' })
    if access.mode == 'player' then
        local ownerCitizenId = MJC.Validation.trim(access.ownerCitizenId or access.owner_citizenid)
        if ownerCitizenId == '' then return false, 'This player-owned stash is missing an owner.' end
        if tostring(player.PlayerData.citizenid or '') ~= ownerCitizenId then return false, 'This stash belongs to another player.' end
    else
        if access.mode ~= 'public' and job.name ~= point.job_name then return false, 'You do not work here.' end

        local grade = currentGrade(job)
        local minGrade = tonumber(access.minGrade) or 0
        if access.mode ~= 'public' and grade < minGrade then return false, 'Your grade cannot use this point.' end
        if access.mode ~= 'public' and type(access.allowedGrades) == 'table' and #access.allowedGrades > 0 then
            local allowed = false
            for i = 1, #access.allowedGrades do
                if tonumber(access.allowedGrades[i]) == grade then allowed = true break end
            end
            if not allowed then return false, 'Your grade cannot use this point.' end
        end

        local duty = access.duty or 'any'
        if access.mode ~= 'public' and duty == 'on' and not isOnDuty(job) then return false, 'Go on duty first.' end
        if access.mode ~= 'public' and duty == 'off' and isOnDuty(job) then return false, 'Go off duty first.' end
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'Player entity unavailable.' end
    local coords = GetEntityCoords(ped)
    local target = vector3(tonumber(point.x), tonumber(point.y), tonumber(point.z))
    local allowedDistance = tonumber(maxDistance) or tonumber(point.radius) or 3.0
    allowedDistance = math.max(allowedDistance, 1.5) + 0.75
    if #(coords - target) > allowedDistance then return false, 'Move closer to the point.' end

    return true, player
end
