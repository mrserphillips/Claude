MJC = MJC or {}
MJC.Validation = {}

local V = MJC.Validation

function V.isEnabled(value)
    return value == true or tonumber(value) == 1
end

function V.trim(value)
    if type(value) ~= 'string' then return '' end
    return value:match('^%s*(.-)%s*$') or ''
end

function V.jobName(value)
    value = V.trim(value):lower()
    if #value < 2 or #value > 32 then return nil, 'Job name must be 2-32 characters.' end
    if not value:match('^[a-z][a-z0-9_]*$') then
        return nil, 'Job name must start with a letter and use only lowercase letters, numbers and underscores.'
    end
    return value
end

function V.label(value, field, maxLength)
    value = V.trim(value)
    maxLength = maxLength or 64
    if value == '' then return nil, (field or 'Label') .. ' is required.' end
    if #value > maxLength then return nil, (field or 'Label') .. ' is too long.' end
    return value
end

function V.integer(value, min, max, field)
    local number = tonumber(value)
    if not number or number % 1 ~= 0 then return nil, (field or 'Value') .. ' must be a whole number.' end
    if min and number < min then return nil, (field or 'Value') .. ' is too small.' end
    if max and number > max then return nil, (field or 'Value') .. ' is too large.' end
    return number
end

function V.price(value)
    return V.integer(value, 0, 100000000, 'Price')
end

function V.decode(value, fallback)
    if type(value) == 'table' then return value end
    if not value or value == '' then return fallback or {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return fallback or {}
end

function V.encode(value)
    return json.encode(value or {})
end

function V.grades(grades)
    if type(grades) ~= 'table' or #grades == 0 then return nil, 'At least one grade is required.' end
    local normalized = {}
    local seen = {}
    for index = 1, #grades do
        local grade = grades[index]
        local level, levelError = V.integer(grade.level, 0, 50, 'Grade level')
        if not level then return nil, levelError end
        if seen[level] then return nil, ('Grade %s is duplicated.'):format(level) end
        seen[level] = true
        local name, nameError = V.label(grade.name or grade.label, 'Grade name', 48)
        if not name then return nil, nameError end
        local payment, payError = V.integer(grade.payment or 0, 0, 1000000, 'Grade payment')
        if not payment then return nil, payError end
        normalized[#normalized + 1] = {
            level = level,
            name = name,
            payment = payment,
            isboss = grade.isboss == true,
            bankAuth = grade.bankAuth == true or grade.isboss == true,
        }
    end
    table.sort(normalized, function(a, b) return a.level < b.level end)
    if normalized[1].level ~= 0 then return nil, 'Jobs must include grade 0.' end
    return normalized
end


local function normalizeAllowedGrades(value)
    if type(value) ~= 'table' then return {} end
    local result, seen = {}, {}
    for _, raw in pairs(value) do
        local grade = tonumber(raw)
        if grade and grade % 1 == 0 and grade >= 0 and grade <= 50 and not seen[grade] then
            seen[grade] = true
            result[#result + 1] = grade
        end
    end
    table.sort(result)
    return result
end

function V.point(payload)
    if type(payload) ~= 'table' then return nil, 'Point payload is invalid.' end
    local label, labelError = V.label(payload.label, 'Point label')
    if not label then return nil, labelError end
    local pointType = V.trim(payload.point_type)
    if not MJC.PointTypes or not MJC.PointTypes.ACTIONS[pointType] then
        return nil, 'Unsupported point type.'
    end

    local rawAccess = type(payload.access) == 'table' and payload.access or {}
    local rawAccessMode = V.trim(rawAccess.mode):lower()
    local playerOwnedStash = pointType == 'stash' and rawAccessMode == 'player'
    local rawJobName = V.trim(payload.job_name):lower()
    local allowsStandalone = pointType == 'shop' or pointType == 'sell' or playerOwnedStash
    local jobName
    if playerOwnedStash then
        jobName = ''
    elseif rawJobName == '' and allowsStandalone then
        jobName = ''
    else
        local jobError
        jobName, jobError = V.jobName(rawJobName)
        if not jobName then return nil, jobError end
    end
    local presentationType = V.trim(payload.presentation_type or 'target')
    if not MJC.PointTypes.PRESENTATIONS[presentationType] then
        return nil, 'Unsupported presentation type.'
    end

    local position = type(payload.position) == 'table' and payload.position or payload
    local x, y, z = tonumber(position.x), tonumber(position.y), tonumber(position.z)
    if not x or not y or not z then return nil, 'Place the point in-world before saving it.' end

    local radius = tonumber(payload.radius) or 2.0
    radius = math.max(0.5, math.min(10.0, radius))
    local minGrade = tonumber(rawAccess.minGrade) or 0
    minGrade = math.max(0, math.min(50, math.floor(minGrade)))
    local duty = V.trim(rawAccess.duty or 'any')
    if duty ~= 'any' and duty ~= 'on' and duty ~= 'off' then duty = 'any' end

    local hours = type(payload.hours) == 'table' and payload.hours or { enabled = false }
    hours = {
        enabled = hours.enabled == true,
        start = math.max(0, math.min(23, math.floor(tonumber(hours.start) or 8))),
        finish = math.max(0, math.min(23, math.floor(tonumber(hours.finish) or 22))),
    }

    local ownerCitizenId = V.trim(rawAccess.ownerCitizenId or rawAccess.owner_citizenid)
    if playerOwnedStash and ownerCitizenId == '' then
        return nil, 'Owner Citizen ID is required for a player-owned stash.'
    end
    if #ownerCitizenId > 64 then return nil, 'Owner Citizen ID is too long.' end

    local normalizedMode = rawAccess.mode == 'public' and 'public' or 'job'
    if playerOwnedStash then normalizedMode = 'player' end
    local normalizedAccess = {
        mode = normalizedMode,
        minGrade = minGrade,
        allowedGrades = normalizeAllowedGrades(rawAccess.allowedGrades),
        duty = duty,
        ownerCitizenId = ownerCitizenId,
    }
    if jobName == '' and not playerOwnedStash then normalizedAccess.mode = 'public' end

    return {
        id = tonumber(payload.id),
        label = label,
        job_name = jobName,
        point_type = pointType,
        presentation_type = presentationType,
        x = x, y = y, z = z, heading = tonumber(position.heading) or tonumber(payload.heading) or 0.0,
        radius = radius,
        access = normalizedAccess,
        presentation = type(payload.presentation) == 'table' and payload.presentation or {},
        config = type(payload.config) == 'table' and payload.config or {},
        blip = type(payload.blip) == 'table' and payload.blip or {},
        hours = hours,
        enabled = payload.enabled ~= false,
    }
end
