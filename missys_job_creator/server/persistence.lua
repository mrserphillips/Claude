MJC = MJC or {}
MJC.Persistence = {}
MJC.State = MJC.State or { jobs = {}, businesses = {}, npcs = {}, shops = {}, activities = {}, points = {}, blips = {}, fleet = {} }

local P = MJC.Persistence

local function byId(rows)
    local result = {}
    for i = 1, #rows do result[rows[i].id] = rows[i] end
    return result
end

local function rowsForJob(map, jobName)
    local result = {}
    for _, row in pairs(map or {}) do
        if row.job_name == jobName then result[#result + 1] = row end
    end
    table.sort(result, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
    return result
end

function P.loadAll()
    local jobs = MySQL.query.await('SELECT * FROM missys_job_creator_jobs ORDER BY id') or {}
    local grades = MySQL.query.await('SELECT * FROM missys_job_creator_grades ORDER BY job_id, grade_level') or {}
    local businesses = MySQL.query.await('SELECT * FROM missys_job_creator_businesses ORDER BY id') or {}
    local npcs = MySQL.query.await('SELECT * FROM missys_job_creator_npcs ORDER BY id') or {}
    local shops = MySQL.query.await('SELECT * FROM missys_job_creator_shops ORDER BY id') or {}
    local items = MySQL.query.await('SELECT * FROM missys_job_creator_shop_items ORDER BY shop_id, sort_order, id') or {}
    local activities = MySQL.query.await('SELECT * FROM missys_job_creator_activities ORDER BY id') or {}
    local points = MySQL.query.await('SELECT * FROM missys_job_creator_points ORDER BY id') or {}
    local blips = MySQL.query.await('SELECT * FROM missys_job_creator_blips ORDER BY id') or {}
    local fleet = MySQL.query.await('SELECT * FROM missys_job_creator_fleet ORDER BY id') or {}

    local jobMap = byId(jobs)
    for _, job in pairs(jobMap) do
        job.grades = {}
        job.settings = MJC.Validation.decode(job.settings_json, {})
    end
    for i = 1, #grades do
        local grade = grades[i]
        if jobMap[grade.job_id] then
            jobMap[grade.job_id].grades[#jobMap[grade.job_id].grades + 1] = grade
        end
    end

    local shopMap = byId(shops)
    for _, shop in pairs(shopMap) do
        shop.items = {}
        shop.access = MJC.Validation.decode(shop.access_json, { mode = 'public' })
        shop.hours = MJC.Validation.decode(shop.hours_json, { enabled = false })
        shop.revenue = MJC.Validation.decode(shop.revenue_json, {})
    end
    for i = 1, #items do
        if shopMap[items[i].shop_id] then
            shopMap[items[i].shop_id].items[#shopMap[items[i].shop_id].items + 1] = items[i]
        end
    end

    local npcMap = byId(npcs)
    for _, npc in pairs(npcMap) do
        npc.access = MJC.Validation.decode(npc.access_json, { mode = 'public' })
        npc.hours = MJC.Validation.decode(npc.hours_json, { enabled = false })
        npc.blip = MJC.Validation.decode(npc.blip_json, {})
        npc.animation = MJC.Validation.decode(npc.animation_json, {})
    end

    local pointMap = byId(points)
    for _, point in pairs(pointMap) do
        point.access = MJC.Validation.decode(point.access_json, { minGrade = 0, duty = 'any' })
        point.presentation = MJC.Validation.decode(point.presentation_json, {})
        point.config = MJC.Validation.decode(point.config_json, {})
        point.blip = MJC.Validation.decode(point.blip_json, {})
        point.hours = MJC.Validation.decode(point.hours_json, { enabled = false })
    end

    local blipMap = byId(blips)
    for _, blip in pairs(blipMap) do
        blip.access = MJC.Validation.decode(blip.access_json, { mode = 'public', minGrade = 0 })
    end

    MJC.State = {
        jobs = jobMap,
        businesses = byId(businesses),
        npcs = npcMap,
        shops = shopMap,
        activities = byId(activities),
        points = pointMap,
        blips = blipMap,
        fleet = byId(fleet),
    }
    return MJC.State
end

function P.publicState()
    return MJC.State
end

function P.refreshAndBroadcast()
    P.loadAll()
    TriggerClientEvent('missys_job_creator:client:state', -1, P.publicState())
    return MJC.State
end

function P.findJobByName(name)
    for _, job in pairs(MJC.State.jobs) do
        if job.job_name == name then return job end
    end
end

function P.findBusinessByJob(name)
    for _, business in pairs(MJC.State.businesses) do
        if business.job_name == name then return business end
    end
end

function P.findShopForNpc(npcId)
    for _, shop in pairs(MJC.State.shops) do
        if tonumber(shop.npc_id) == tonumber(npcId) and MJC.Validation.isEnabled(shop.enabled) then return shop end
    end
end

function P.findPoint(id)
    return MJC.State.points and MJC.State.points[tonumber(id)] or nil
end

function P.pointsForJob(jobName)
    return rowsForJob(MJC.State.points, jobName)
end

function P.fleetForJob(jobName)
    return rowsForJob(MJC.State.fleet, jobName)
end

function P.blipsForJob(jobName)
    return rowsForJob(MJC.State.blips, jobName)
end
