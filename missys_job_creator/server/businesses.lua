MJC = MJC or {}
MJC.Businesses = {}

local B = MJC.Businesses

local function sameCoords(a, b)
    return math.abs(a.x - b.x) < 0.05 and math.abs(a.y - b.y) < 0.05 and math.abs(a.z - b.z) < 0.05
end

function B.stockCoords(business)
    local coords = {}

    local function add(x, y, z)
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if not x or not y or not z then return end
        local candidate = vector3(x, y, z)
        for i = 1, #coords do
            if sameCoords(coords[i], candidate) then return end
        end
        coords[#coords + 1] = vector3(x, y, z)
    end

    add(business.stock_x, business.stock_y, business.stock_z)

    for _, shop in pairs(MJC.State.shops or {}) do
        if MJC.Validation.isEnabled(shop.enabled)
            and shop.stock_mode == 'business'
            and shop.business_job == business.job_name
            and shop.npc_id then
            local npc = MJC.State.npcs[tonumber(shop.npc_id)]
            if npc and MJC.Validation.isEnabled(npc.enabled) then
                add(npc.x, npc.y, npc.z)
            end
        end
    end

    if #coords == 0 then return nil end
    if #coords == 1 then return coords[1] end
    return coords
end

function B.registerStash(business)
    if not MJC.Validation.isEnabled(business.enabled) then return end
    local groups = { [business.job_name] = 0 }
    local coords = B.stockCoords(business)
    exports.ox_inventory:RegisterStash(
        business.stash_id,
        business.label .. ' Stock',
        tonumber(business.stash_slots) or Config.BusinessStash.slots,
        tonumber(business.stash_weight) or Config.BusinessStash.maxWeight,
        false,
        groups,
        coords
    )
end

function B.prepareStock(source, businessJob)
    local normalized, jobError = MJC.Validation.jobName(businessJob)
    if not normalized then return false, jobError end

    local business = MJC.Persistence.findBusinessByJob(normalized)
    if not business or not MJC.Validation.isEnabled(business.enabled) then
        return false, 'Business stock is unavailable.'
    end

    if exports.qbx_core:HasGroup(source, { [business.job_name] = 0 }) ~= true then
        return false, 'You do not have access to this business stock.'
    end

    B.registerStash(business)
    return true, business.stash_id
end

function B.restore()
    local count = 0
    for _, business in pairs(MJC.State.businesses) do
        if MJC.Validation.isEnabled(business.enabled) then
            B.registerStash(business)
            count = count + 1
        end
    end
    return count
end

function B.save(payload)
    local label, labelError = MJC.Validation.label(payload.label, 'Business label')
    if not label then return false, labelError end
    local jobName, jobError = MJC.Validation.jobName(payload.job_name)
    if not jobName then return false, jobError end
    if not exports.qbx_core:GetJob(jobName) then return false, 'Create the QBX job before creating its business link.' end

    local stashId = MJC.Validation.trim(payload.stash_id)
    if stashId == '' then stashId = 'mjc_business_' .. jobName end
    if not stashId:match('^[%w_%-]+$') then return false, 'Stash ID can only contain letters, numbers, underscores and hyphens.' end

    local id = tonumber(payload.id)
    local slots, slotsError = MJC.Validation.integer(payload.stash_slots or Config.BusinessStash.slots, 10, 500, 'Stash slots')
    if not slots then return false, slotsError end
    local weight, weightError = MJC.Validation.integer(payload.stash_weight or Config.BusinessStash.maxWeight, 1000, 10000000, 'Stash weight')
    if not weight then return false, weightError end
    local position = payload.stock or {}
    local revenueAccount = MJC.Validation.trim(payload.revenue_account)
    if revenueAccount == '' then revenueAccount = jobName end
    local enabled = payload.enabled == false and 0 or 1

    if id then
        MySQL.update.await([[
            UPDATE missys_job_creator_businesses SET label=?, job_name=?, stash_id=?, stash_slots=?, stash_weight=?, revenue_account=?, stock_x=?, stock_y=?, stock_z=?, enabled=? WHERE id=?
        ]], { label, jobName, stashId, slots, weight, revenueAccount, tonumber(position.x), tonumber(position.y), tonumber(position.z), enabled, id })
    else
        if MJC.Persistence.findBusinessByJob(jobName) then return false, 'That job already has a business link.' end
        id = MySQL.insert.await([[
            INSERT INTO missys_job_creator_businesses (label, job_name, stash_id, stash_slots, stash_weight, revenue_account, stock_x, stock_y, stock_z, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { label, jobName, stashId, slots, weight, revenueAccount, tonumber(position.x), tonumber(position.y), tonumber(position.z), enabled })
    end
    return true, id
end



function B.ensureLink(jobName)
    local normalized, jobError = MJC.Validation.jobName(jobName)
    if not normalized then return false, jobError end

    local existing = MJC.Persistence.findBusinessByJob(normalized)
    if existing then return true, existing end

    local rows = MySQL.query.await('SELECT * FROM missys_job_creator_businesses WHERE job_name = ? LIMIT 1', { normalized }) or {}
    if rows[1] then return true, rows[1] end

    local job = exports.qbx_core:GetJob(normalized)
    if not job then return false, ('QBX job "%s" does not exist.'):format(normalized) end

    local label = MJC.Validation.trim(job.label)
    if label == '' then label = normalized end
    local stashId = 'mjc_business_' .. normalized
    local slots = Config.BusinessStash.slots
    local weight = Config.BusinessStash.maxWeight
    local revenueAccount = normalized

    local id = MySQL.insert.await([[
        INSERT INTO missys_job_creator_businesses
        (label, job_name, stash_id, stash_slots, stash_weight, revenue_account, stock_x, stock_y, stock_z, enabled)
        VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, 1)
    ]], { label, normalized, stashId, slots, weight, revenueAccount })

    return true, {
        id = id,
        label = label,
        job_name = normalized,
        stash_id = stashId,
        stash_slots = slots,
        stash_weight = weight,
        revenue_account = revenueAccount,
        enabled = 1,
    }
end

function B.delete(id)
    id = tonumber(id)
    local business = id and MJC.State.businesses[id]
    if not business then return false, 'Business not found.' end
    local used = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_shops WHERE business_job = ?', { business.job_name })) or 0
    if used > 0 then return false, 'This business is still linked to a shop.' end
    MySQL.query.await('DELETE FROM missys_job_creator_businesses WHERE id = ?', { id })
    return true
end
