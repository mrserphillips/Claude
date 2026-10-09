--[[
    Velora City — Starter Pack (server)

    Redemption model (restart-safe, duplicate-proof):

      1. velora_starterpack_claims has a UNIQUE(citizenid) row. The first confirmed
         choice inserts it with status 'pending' and locks in the path forever.
      2. Processing takes a DB lock on that row (lock_token / lock_at) plus an
         in-memory lock, so two requests can never pay out at the same time.
      3. Every reward is split into "steps" (one per stackable item, one per unit
         of a non-stackable item, one per money account). Each step is written as
         'granting' BEFORE it is given and 'granted' right AFTER. A step that is
         already 'granted' is never given again.
      4. A step found in 'granting' state means the server stopped between those
         two writes. We cannot know whether it was delivered, so it is NEVER
         re-granted automatically; it is flagged 'review' for staff instead.
         This guarantees no duplicates even across crashes.
      5. A failed grant (e.g. inventory full) removes the 'granting' marker (the
         item/money was provably not given) and leaves the claim 'pending', so the
         player can make space and retry with /starterpack.
      6. The claim only becomes 'completed' when every step is 'granted' (or
         flagged for review).
]]

local RESOURCE = GetCurrentResourceName()
local Rewards = Config.Rewards
local Msg = Config.Notify.messages

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------
local function logInfo(msg, ...)
    print(('^5[%s]^7 %s'):format(RESOURCE, msg:format(...)))
end

local function logWarn(msg, ...)
    print(('^3[%s] WARNING:^7 %s'):format(RESOURCE, msg:format(...)))
end

local function logError(msg, ...)
    print(('^1[%s] ERROR:^7 %s'):format(RESOURCE, msg:format(...)))
end

local function logDebug(msg, ...)
    if Config.Debug then
        print(('^6[%s] DEBUG:^7 %s'):format(RESOURCE, msg:format(...)))
    end
end

local function webhook(title, description, color)
    local url = Config.Logging.webhook
    if not url or url == '' then return end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = Config.Logging.webhookName,
        embeds = { {
            title = title,
            description = description,
            color = color or 16732067,
            footer = { text = RESOURCE },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function notify(src, description, nType)
    if not src or src <= 0 then return end
    TriggerClientEvent('ox_lib:notify', src, {
        title = Config.Notify.title,
        description = description,
        type = nType or 'inform',
        position = Config.Notify.position,
        duration = Config.Notify.duration,
    })
end

local function nowMs()
    return GetGameTimer()
end

local function randomToken()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local out = {}
    for i = 1, 32 do
        local n = math.random(1, #chars)
        out[i] = chars:sub(n, n)
    end
    return table.concat(out)
end

math.randomseed(os.time() + GetGameTimer())

---@return table|nil player, string|nil citizenid
local function getPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return nil end
    return player, player.PlayerData.citizenid
end

local function isLoggedIn(src)
    local state = Player(src).state
    return state and state.isLoggedIn == true
end

local function charName(player)
    local info = player and player.PlayerData and player.PlayerData.charinfo
    if not info then return nil end
    return ('%s %s'):format(info.firstname or '?', info.lastname or '?')
end

local function playerLabel(src)
    if src == 0 then return 'console' end
    local license = GetPlayerIdentifierByType(src, 'license') or 'unknown'
    return ('%s (%s | %s)'):format(GetPlayerName(src) or 'unknown', src, license)
end

local function getItemDef(name)
    local ok, def = pcall(function() return exports.ox_inventory:Items(name) end)
    if ok then return def end
    return nil
end

-- oxmysql returns DATETIME columns as millisecond timestamps by default.
local function fmtDate(v)
    if type(v) == 'number' then return os.date('%Y-%m-%d %H:%M', math.floor(v / 1000)) end
    return v and tostring(v) or 'n/a'
end

local function isTrue(v)
    return v == true or v == 1
end

local function isPositiveInt(v)
    return type(v) == 'number' and v >= 1 and v == math.floor(v) and v < 2^31
end

local function isNonNegativeInt(v)
    return type(v) == 'number' and v >= 0 and v == math.floor(v) and v < 2^31
end

---------------------------------------------------------------------------
-- Config validation
---------------------------------------------------------------------------
local configErrors = {}

local function validateConfig()
    configErrors = {}

    local function checkItems(list, where)
        if type(list) ~= 'table' then
            configErrors[#configErrors + 1] = ('%s.items is not a table'):format(where)
            return
        end
        for i, entry in ipairs(list) do
            if type(entry) ~= 'table' or type(entry.name) ~= 'string' or entry.name == '' then
                configErrors[#configErrors + 1] = ('%s.items[%d] has no valid name'):format(where, i)
            elseif not isPositiveInt(entry.count) then
                configErrors[#configErrors + 1] = ('%s.items[%d] (%s) has an invalid count'):format(where, i, entry.name)
            elseif not getItemDef(entry.name) then
                configErrors[#configErrors + 1] = ('item "%s" (%s) does not exist in ox_inventory — add it to ox_inventory/data/items.lua'):format(entry.name, where)
            end
        end
    end

    local function checkMoney(money, where)
        if money == nil then return end
        if type(money) ~= 'table' then
            configErrors[#configErrors + 1] = ('%s.money is not a table'):format(where)
            return
        end
        for account, amount in pairs(money) do
            if account ~= 'cash' and account ~= 'bank' then
                configErrors[#configErrors + 1] = ('%s.money.%s is not a supported account (cash/bank)'):format(where, tostring(account))
            elseif not isNonNegativeInt(amount) then
                configErrors[#configErrors + 1] = ('%s.money.%s must be a whole number >= 0'):format(where, account)
            end
        end
    end

    checkItems(Rewards.standard.items, 'standard')
    checkMoney(Rewards.standard.money, 'standard')

    for key, path in pairs(Rewards.paths) do
        if type(key) ~= 'string' or not key:match('^[%w_]+$') or #key > 32 then
            configErrors[#configErrors + 1] = ('path key "%s" must be alphanumeric/underscore and <= 32 chars'):format(tostring(key))
        end
        checkItems(path.items or {}, ('paths.%s'):format(key))
        checkMoney(path.money, ('paths.%s'):format(key))
    end

    for _, key in ipairs(Rewards.pathOrder) do
        if not Rewards.paths[key] then
            configErrors[#configErrors + 1] = ('pathOrder contains "%s" which is not defined in paths'):format(key)
        end
    end

    if #configErrors > 0 then
        for _, err in ipairs(configErrors) do logError('Config: %s', err) end
        logError('%d configuration problem(s) found. Claims are BLOCKED until fixed so nobody receives a broken pack.', #configErrors)
    else
        logInfo('Configuration validated — all reward items exist in ox_inventory.')
    end

    return #configErrors == 0
end

---------------------------------------------------------------------------
-- Reward planning (everything derived from server config only)
---------------------------------------------------------------------------
local function moneyFor(pathKey)
    local std = Rewards.standard.money or {}
    local extra = Rewards.paths[pathKey].money or {}
    return {
        cash = (std.cash or 0) + (extra.cash or 0),
        bank = (std.bank or 0) + (extra.bank or 0),
    }
end

-- Merges standard + path items into one list. Plain items with the same name
-- are combined; items with metadata are kept separate.
local function mergedItems(pathKey)
    local merged, order = {}, {}

    local function add(list)
        for i, entry in ipairs(list or {}) do
            local key
            if entry.metadata and next(entry.metadata) then
                key = ('%s@%d_%d'):format(entry.name, #order + 1, i)
            else
                key = entry.name
            end
            if merged[key] then
                merged[key].count += entry.count
            else
                merged[key] = { key = key, name = entry.name, count = entry.count, metadata = entry.metadata }
                order[#order + 1] = key
            end
        end
    end

    add(Rewards.standard.items)
    add(Rewards.paths[pathKey].items)

    local out = {}
    for i, key in ipairs(order) do out[i] = merged[key] end
    return out
end

-- Builds the ordered list of grant steps. Items first, money last.
local function buildSteps(pathKey)
    local steps = {}

    for _, entry in ipairs(mergedItems(pathKey)) do
        local def = getItemDef(entry.name)
        if not def then return nil, entry.name end

        if def.stack == false then
            -- Non-stackable: one step per unit, so a partial failure can never
            -- leave us unsure how many were delivered.
            for unit = 1, entry.count do
                steps[#steps + 1] = {
                    key = ('item:%s#%d'):format(entry.key, unit),
                    kind = 'item', name = entry.name, count = 1,
                    metadata = entry.metadata, def = def,
                }
            end
        else
            steps[#steps + 1] = {
                key = ('item:%s'):format(entry.key),
                kind = 'item', name = entry.name, count = entry.count,
                metadata = entry.metadata, def = def,
            }
        end
    end

    local money = moneyFor(pathKey)
    for _, account in ipairs({ 'cash', 'bank' }) do
        if money[account] > 0 then
            steps[#steps + 1] = { key = ('money:%s'):format(account), kind = 'money', account = account, count = money[account] }
        end
    end

    return steps
end

local function imageFor(name)
    return Config.Inventory.imagePath:format(name)
end

local function displayItems(list)
    local out = {}
    for _, entry in ipairs(list or {}) do
        local def = getItemDef(entry.name)
        out[#out + 1] = {
            name = entry.name,
            label = def and def.label or entry.name,
            count = entry.count,
            image = imageFor(entry.name),
        }
    end
    return out
end

local function displayMoney(money)
    money = money or {}
    return { cash = money.cash or 0, bank = money.bank or 0 }
end

local function buildUiPayload(row, token, openedBy)
    local paths = {}
    for _, key in ipairs(Rewards.pathOrder) do
        local p = Rewards.paths[key]
        if p then
            paths[#paths + 1] = {
                key = key,
                label = p.label,
                title = p.title,
                subtitle = p.subtitle,
                description = p.description,
                theme = p.theme or key,
                tags = p.tags or {},
                items = displayItems(p.items),
                money = displayMoney(p.money),
            }
        end
    end

    return {
        token = token,
        ui = Config.UI,
        paths = paths,
        standard = {
            items = displayItems(Rewards.standard.items),
            money = displayMoney(Rewards.standard.money),
        },
        resume = row and row.status == 'pending' and { path = row.path } or nil,
        openedBy = openedBy,
    }
end

-- Full list (standard + path) used for the reward screen.
local function rewardSummary(pathKey)
    return {
        items = displayItems(mergedItems(pathKey)),
        money = moneyFor(pathKey),
    }
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local dbReady = false

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `velora_starterpack_claims` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `license` VARCHAR(100) NULL DEFAULT NULL,
        `char_name` VARCHAR(100) NULL DEFAULT NULL,
        `path` VARCHAR(32) NOT NULL,
        `status` ENUM('pending', 'completed') NOT NULL DEFAULT 'pending',
        `needs_review` TINYINT(1) NOT NULL DEFAULT 0,
        `attempts` INT UNSIGNED NOT NULL DEFAULT 0,
        `lock_token` VARCHAR(64) NULL DEFAULT NULL,
        `lock_at` DATETIME NULL DEFAULT NULL,
        `opened_by` VARCHAR(100) NULL DEFAULT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `completed_at` DATETIME NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_vsp_claims_citizenid` (`citizenid`),
        KEY `idx_vsp_claims_status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `velora_starterpack_rewards` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `step_key` VARCHAR(96) NOT NULL,
        `status` ENUM('granting', 'granted', 'review') NOT NULL DEFAULT 'granting',
        `amount` INT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_vsp_rewards_step` (`citizenid`, `step_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `velora_starterpack_history` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `action` VARCHAR(32) NOT NULL,
        `path` VARCHAR(32) NULL DEFAULT NULL,
        `actor` VARCHAR(100) NULL DEFAULT NULL,
        `details` TEXT NULL DEFAULT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_vsp_history_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

local function dbCall(fn, query, params)
    local ok, result = pcall(fn, query, params)
    if not ok then
        logError('Database query failed: %s', tostring(result))
        return nil, true
    end
    return result, false
end

local function getClaim(citizenid)
    local row, err = dbCall(MySQL.single.await, 'SELECT * FROM `velora_starterpack_claims` WHERE `citizenid` = ? LIMIT 1', { citizenid })
    return row, err
end

local function addHistory(citizenid, action, path, actor, details)
    MySQL.insert('INSERT INTO `velora_starterpack_history` (`citizenid`, `action`, `path`, `actor`, `details`) VALUES (?, ?, ?, ?, ?)', {
        citizenid, action, path, actor, details,
    })
end

local function getStepRows(citizenid)
    local rows, err = dbCall(MySQL.query.await, 'SELECT `step_key`, `status`, `amount` FROM `velora_starterpack_rewards` WHERE `citizenid` = ?', { citizenid })
    if err then return nil end
    local map = {}
    for _, r in ipairs(rows or {}) do map[r.step_key] = r end
    return map
end

---------------------------------------------------------------------------
-- In-memory state (all cleared on drop / logout)
---------------------------------------------------------------------------
local sessions = {}        -- [src] = { token, citizenid }
local processingCid = {}   -- [citizenid] = true
local processingSrc = {}   -- [src] = true
local lastClaim = {}       -- [src] = ms
local lastOpen = {}        -- [src] = ms
local strikes = {}         -- [src] = count
local pendingResets = {}   -- ['adminSrc:citizenid'] = os.time()

local function strike(src, what)
    strikes[src] = (strikes[src] or 0) + 1
    if strikes[src] == Config.Security.spamLogThreshold or strikes[src] % 25 == 0 then
        logWarn('Possible spam/exploit attempt: %s triggered %s rate limit %d times', playerLabel(src), what, strikes[src])
        webhook('Rate limit triggered', ('%s hit the %s rate limit %d times'):format(playerLabel(src), what, strikes[src]), 15548997)
    end
end

local function clearPlayer(src)
    sessions[src] = nil
    processingSrc[src] = nil
    lastClaim[src] = nil
    lastOpen[src] = nil
    strikes[src] = nil
end

AddEventHandler('playerDropped', function()
    clearPlayer(source)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if type(src) == 'number' then
        sessions[src] = nil
    end
end)

---------------------------------------------------------------------------
-- Opening the menu
---------------------------------------------------------------------------

---@return table|nil payload, string|nil errorMessage
local function prepareOpen(src, openedBy)
    if not Config.Enabled then return nil, Msg.disabled end
    if not isLoggedIn(src) then return nil, Msg.notLoaded end

    local player, citizenid = getPlayer(src)
    if not player then return nil, Msg.notLoaded end
    if not dbReady then return nil, Msg.dbError end

    local row, err = getClaim(citizenid)
    if err then return nil, Msg.dbError end
    if row and row.status == 'completed' then return nil, Msg.alreadyClaimed end

    if row and not Rewards.paths[row.path] then
        logError('Character %s has a pending claim for unknown path "%s" (removed from config?). Staff must /%s them.',
            citizenid, tostring(row.path), Config.Admin.commands.reset)
        return nil, Msg.configError
    end

    local token = randomToken()
    sessions[src] = { token = token, citizenid = citizenid }

    return buildUiPayload(row, token, openedBy)
end

local function canOpenNow(src)
    local t = nowMs()
    if lastOpen[src] and t - lastOpen[src] < Config.Security.openCooldown then
        strike(src, 'open')
        return false
    end
    lastOpen[src] = t
    return true
end

-- Client asks after its own readiness checks (auto-open), or via the
-- OpenIfEligible export. Silent on failure so auto-open never spams notifications.
lib.callback.register('velora_starterpack:server:requestOpen', function(src, isAuto)
    if isAuto == true and not Config.AutoOpen.enabled then return nil end
    if not canOpenNow(src) then return nil end

    local payload = prepareOpen(src, nil)
    return payload
end)

-- Client-side config (only what the client needs, no reward data).
lib.callback.register('velora_starterpack:server:getClientConfig', function()
    return {
        enabled = Config.Enabled,
        debug = Config.Debug,
        autoOpen = Config.AutoOpen,
        command = Config.Command,
        admin = { commands = Config.Admin.commands },
    }
end)

-- Player closed the UI without claiming: invalidate the session token.
RegisterNetEvent('velora_starterpack:server:closed', function()
    local src = source
    if not processingSrc[src] then
        sessions[src] = nil
    end
end)

if Config.Command.enabled then
    RegisterCommand(Config.Command.name, function(src)
        if src <= 0 then return end
        if not canOpenNow(src) then
            notify(src, Msg.cooldown, 'error')
            return
        end

        local payload, errMsg = prepareOpen(src, nil)
        if not payload then
            notify(src, errMsg, errMsg == Msg.alreadyClaimed and 'inform' or 'error')
            return
        end

        TriggerClientEvent('velora_starterpack:client:open', src, payload)
    end, false)
end

---------------------------------------------------------------------------
-- Inventory capacity check
---------------------------------------------------------------------------

---@return boolean ok, integer needSlots, number needWeight
local function checkCapacity(src, steps)
    local inv = exports.ox_inventory:GetInventory(src)
    if not inv or not inv.slots then
        logError('Could not read ox_inventory inventory for %s', playerLabel(src))
        return false, 0, 0
    end

    local items = inv.items or {}
    local usedSlots = 0
    local plainSlotOf = {} -- item name -> true when a metadata-free stack exists

    for _, slotData in pairs(items) do
        if type(slotData) == 'table' and slotData.name then
            usedSlots += 1
            if not slotData.metadata or next(slotData.metadata) == nil then
                plainSlotOf[slotData.name] = true
            end
        end
    end

    local freeSlots = inv.slots - usedSlots
    local freeWeight = (inv.maxWeight or 0) - (inv.weight or 0)
    local needSlots, needWeight = 0, 0

    for _, step in ipairs(steps) do
        if step.kind == 'item' then
            local def = step.def
            local unitWeight = (step.metadata and step.metadata.weight) or def.weight or 0
            needWeight += unitWeight * step.count

            local canJoinExisting = def.stack ~= false
                and not step.metadata
                and not def.degrade
                and not step.name:upper():find('^WEAPON_')
                and plainSlotOf[step.name]

            if not canJoinExisting then
                needSlots += 1
            end
        elseif step.kind == 'money' then
            -- qbx_core mirrors cash into the ox_inventory money item.
            local oxName = step.account == 'cash' and Config.Inventory.cashItem or step.account
            local def = getItemDef(oxName)
            if def then
                needWeight += (def.weight or 0) * step.count
                if not plainSlotOf[oxName] then
                    -- Only counts when the account is item-backed; extra caution is harmless.
                    needSlots += 1
                end
            end
        end
    end

    local ok = needSlots <= freeSlots and needWeight <= freeWeight
    logDebug('Capacity for %s: need %d slots / %.0fg, free %d slots / %.0fg -> %s',
        playerLabel(src), needSlots, needWeight, freeSlots, freeWeight, tostring(ok))

    return ok, needSlots, needWeight
end

---------------------------------------------------------------------------
-- Granting
---------------------------------------------------------------------------

-- Returns true if the given step was delivered, false if it provably was not,
-- or nil if the outcome is unknown (an export threw mid-call).
local function grantStep(src, step)
    if step.kind == 'item' then
        local ok, success, response = pcall(function()
            return exports.ox_inventory:AddItem(src, step.name, step.count, step.metadata)
        end)
        if not ok then
            logError('ox_inventory:AddItem threw for %s x%d: %s', step.name, step.count, tostring(success))
            return nil
        end
        if not success then
            logWarn('ox_inventory:AddItem refused %s x%d for %s (%s)', step.name, step.count, playerLabel(src), tostring(response))
            return false, response
        end
        return true
    elseif step.kind == 'money' then
        local ok, success = pcall(function()
            return exports.qbx_core:AddMoney(src, step.account, step.count, Config.MoneyReason)
        end)
        if not ok then
            logError('qbx_core:AddMoney threw for %s %d: %s', step.account, step.count, tostring(success))
            return nil
        end
        if not success then
            logWarn('qbx_core:AddMoney refused %s $%d for %s', step.account, step.count, playerLabel(src))
            return false
        end
        return true
    end
    return false
end

local function savePlayer(src)
    pcall(function() exports.qbx_core:Save(src) end)
end

local function acquireDbLock(citizenid, token)
    local affected, err = dbCall(MySQL.update.await, [[
        UPDATE `velora_starterpack_claims`
           SET `lock_token` = ?, `lock_at` = NOW(), `attempts` = `attempts` + 1
         WHERE `citizenid` = ? AND `status` = 'pending'
           AND (`lock_token` IS NULL OR `lock_at` IS NULL OR `lock_at` < (NOW() - INTERVAL ? SECOND))
    ]], { token, citizenid, Config.Security.lockTimeout })
    return not err and affected == 1
end

local function releaseDbLock(citizenid, token)
    dbCall(MySQL.update.await, 'UPDATE `velora_starterpack_claims` SET `lock_token` = NULL, `lock_at` = NULL WHERE `citizenid` = ? AND `lock_token` = ?', { citizenid, token })
end

local function fail(code, message)
    return { ok = false, error = code, message = message }
end

---Processes (or resumes) a claim. Must be called with in-memory locks held.
local function processClaim(src, citizenid, pathKey, player)
    local lockToken = randomToken()
    if not acquireDbLock(citizenid, lockToken) then
        return fail('busy', Msg.busy)
    end

    local steps, missing = buildSteps(pathKey)
    if not steps then
        releaseDbLock(citizenid, lockToken)
        logError('Item "%s" is missing from ox_inventory; claim for %s aborted before granting anything.', tostring(missing), citizenid)
        return fail('config', Msg.configError)
    end

    local stepRows = getStepRows(citizenid)
    if not stepRows then
        releaseDbLock(citizenid, lockToken)
        return fail('db', Msg.dbError)
    end

    -- Resolve which steps still need granting.
    local pending, needsReview = {}, false
    for _, step in ipairs(steps) do
        local existing = stepRows[step.key]
        if not existing then
            pending[#pending + 1] = step
        elseif existing.status == 'granting' or existing.status == 'review' then
            -- Interrupted mid-grant in an earlier attempt: outcome unknown.
            needsReview = true
            if existing.status == 'granting' then
                dbCall(MySQL.update.await, 'UPDATE `velora_starterpack_rewards` SET `status` = \'review\' WHERE `citizenid` = ? AND `step_key` = ?', { citizenid, step.key })
                logWarn('Step %s for %s was interrupted in a previous attempt — NOT re-granting, flagged for staff review.', step.key, citizenid)
                webhook('Starter pack step needs review', ('citizenid `%s` step `%s` was interrupted (server stop/crash). It was not re-granted to avoid duplication. Check the player manually.'):format(citizenid, step.key), 16705372)
            end
        end
    end

    -- Capacity check for everything still to be granted, before granting anything.
    if #pending > 0 then
        local ok, needSlots, needWeight = checkCapacity(src, pending)
        if not ok then
            releaseDbLock(citizenid, lockToken)
            return fail('inventory_full', Msg.inventoryFull:format(needSlots, needWeight / 1000))
        end
    end

    local grantedNow = 0
    for _, step in ipairs(pending) do
        -- The player must still be the same character, online.
        local current, currentCid = getPlayer(src)
        if not current or currentCid ~= citizenid then
            releaseDbLock(citizenid, lockToken)
            logWarn('Claim for %s interrupted: player left or switched character after %d step(s).', citizenid, grantedNow)
            return fail('interrupted', Msg.grantFailed)
        end

        -- 1) Write the intent. The UNIQUE key stops a parallel writer.
        local insertId, insErr = dbCall(MySQL.insert.await, 'INSERT IGNORE INTO `velora_starterpack_rewards` (`citizenid`, `step_key`, `status`, `amount`) VALUES (?, ?, \'granting\', ?)', { citizenid, step.key, step.count })
        if insErr or not insertId or insertId == 0 then
            releaseDbLock(citizenid, lockToken)
            logError('Could not record step %s for %s (duplicate or DB error) — stopping to avoid duplication.', step.key, citizenid)
            return fail('db', Msg.dbError)
        end

        -- 2) Grant.
        local delivered, reason = grantStep(src, step)

        -- 3) Record the outcome.
        if delivered == true then
            grantedNow += 1
            local _, updErr = dbCall(MySQL.update.await, 'UPDATE `velora_starterpack_rewards` SET `status` = \'granted\' WHERE `citizenid` = ? AND `step_key` = ?', { citizenid, step.key })
            if updErr then
                -- Row remains 'granting' -> treated as review next time, never re-granted.
                releaseDbLock(citizenid, lockToken)
                return fail('db', Msg.dbError)
            end
            if step.kind == 'money' then savePlayer(src) end
        elseif delivered == false then
            -- Provably not delivered: remove the marker so a retry can grant it.
            dbCall(MySQL.update.await, 'DELETE FROM `velora_starterpack_rewards` WHERE `citizenid` = ? AND `step_key` = ? AND `status` = \'granting\'', { citizenid, step.key })
            releaseDbLock(citizenid, lockToken)
            if reason == 'inventory_full' then
                return fail('inventory_full', Msg.grantFailed)
            end
            return fail('grant_failed', Msg.grantFailed)
        else
            -- Unknown outcome: flag it, never re-grant automatically.
            needsReview = true
            dbCall(MySQL.update.await, 'UPDATE `velora_starterpack_rewards` SET `status` = \'review\' WHERE `citizenid` = ? AND `step_key` = ?', { citizenid, step.key })
            webhook('Starter pack step needs review', ('citizenid `%s` step `%s` errored mid-grant; outcome unknown.'):format(citizenid, step.key), 16705372)
        end
    end

    -- All steps handled: complete the claim (only if we still own the lock).
    local affected, err = dbCall(MySQL.update.await, [[
        UPDATE `velora_starterpack_claims`
           SET `status` = 'completed', `completed_at` = NOW(), `needs_review` = ?, `lock_token` = NULL, `lock_at` = NULL
         WHERE `citizenid` = ? AND `lock_token` = ?
    ]], { needsReview and 1 or 0, citizenid, lockToken })

    if err or affected ~= 1 then
        logError('Could not mark claim %s as completed (lock lost or DB error). All granted steps are recorded; a retry will not duplicate them.', citizenid)
        return fail('db', Msg.dbError)
    end

    savePlayer(src)
    addHistory(citizenid, 'completed', pathKey, playerLabel(src), needsReview and 'needs_review' or nil)

    local summary = rewardSummary(pathKey)
    logInfo('%s [%s / %s] completed the %s starter pack (%d step(s) granted this attempt%s).',
        playerLabel(src), citizenid, charName(player) or '?', pathKey, grantedNow, needsReview and ', NEEDS REVIEW' or '')
    webhook('Starter pack claimed', ('**%s**\ncitizenid: `%s`\ncharacter: %s\npath: **%s**%s'):format(
        playerLabel(src), citizenid, charName(player) or '?', pathKey, needsReview and '\n⚠️ needs staff review' or ''), 16732067)

    return {
        ok = true,
        path = pathKey,
        pathLabel = Rewards.paths[pathKey].label,
        rewards = summary,
        needsReview = needsReview,
        message = needsReview and Msg.needsReview or Msg.success:format(Rewards.paths[pathKey].label),
    }
end

lib.callback.register('velora_starterpack:server:claim', function(src, data)
    -- Rate limiting first, before any work.
    local t = nowMs()
    if lastClaim[src] and t - lastClaim[src] < Config.Security.claimCooldown then
        strike(src, 'claim')
        return fail('cooldown', Msg.cooldown)
    end
    lastClaim[src] = t

    if not Config.Enabled then return fail('disabled', Msg.disabled) end
    if #configErrors > 0 then return fail('config', Msg.configError) end
    if not dbReady then return fail('db', Msg.dbError) end

    -- Strict input validation. The client only ever sends a path key + token.
    if type(data) ~= 'table' or type(data.path) ~= 'string' or type(data.token) ~= 'string' then
        strike(src, 'claim-payload')
        return fail('invalid', Msg.invalidPath)
    end

    local pathKey = data.path
    if #pathKey > 32 or not Rewards.paths[pathKey] then
        strike(src, 'claim-path')
        return fail('invalid', Msg.invalidPath)
    end

    if not isLoggedIn(src) then return fail('not_loaded', Msg.notLoaded) end
    local player, citizenid = getPlayer(src)
    if not player then return fail('not_loaded', Msg.notLoaded) end

    -- Must come from a menu the server itself opened for this character.
    local session = sessions[src]
    if not session or session.token ~= data.token or session.citizenid ~= citizenid then
        strike(src, 'claim-session')
        logDebug('Rejected claim from %s: no valid UI session', playerLabel(src))
        return fail('session', Msg.notLoaded)
    end

    if processingSrc[src] or processingCid[citizenid] then
        return fail('busy', Msg.busy)
    end
    processingSrc[src] = true
    processingCid[citizenid] = true

    local ok, result = pcall(function()
        local row, err = getClaim(citizenid)
        if err then return fail('db', Msg.dbError) end

        if row then
            if row.status == 'completed' then return fail('claimed', Msg.alreadyClaimed) end
            if row.path ~= pathKey then
                local locked = Rewards.paths[row.path]
                return fail('path_locked', Msg.pathLocked:format(locked and locked.label or row.path))
            end
        else
            -- First confirmation: lock in the path. UNIQUE(citizenid) makes this atomic.
            local _, insErr = dbCall(MySQL.insert.await, 'INSERT IGNORE INTO `velora_starterpack_claims` (`citizenid`, `license`, `char_name`, `path`, `status`) VALUES (?, ?, ?, ?, \'pending\')', {
                citizenid, player.PlayerData.license, charName(player), pathKey,
            })
            if insErr then return fail('db', Msg.dbError) end

            row, err = getClaim(citizenid)
            if err or not row then return fail('db', Msg.dbError) end
            if row.path ~= pathKey then
                local locked = Rewards.paths[row.path]
                return fail('path_locked', Msg.pathLocked:format(locked and locked.label or row.path))
            end
            if row.status == 'completed' then return fail('claimed', Msg.alreadyClaimed) end

            addHistory(citizenid, 'chosen', pathKey, playerLabel(src), nil)
            logInfo('%s [%s] chose the %s path.', playerLabel(src), citizenid, pathKey)
        end

        return processClaim(src, citizenid, pathKey, player)
    end)

    processingSrc[src] = nil
    processingCid[citizenid] = nil

    if not ok then
        logError('Unexpected error while processing claim for %s: %s', citizenid, tostring(result))
        return fail('error', Msg.grantFailed)
    end

    if result.ok then
        sessions[src] = nil
    else
        -- Tell the UI which path is locked in so it can switch to resume mode.
        local row = getClaim(citizenid)
        if row and row.status == 'pending' then result.lockedPath = row.path end
        logDebug('Claim for %s not completed: %s', citizenid, tostring(result.error))
    end

    return result
end)

---------------------------------------------------------------------------
-- Admin commands
---------------------------------------------------------------------------
local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(tostring(src), Config.Admin.ace)
end

local function reply(src, message, nType)
    if src == 0 then
        print(('[%s] %s'):format(RESOURCE, message))
        return
    end
    notify(src, message, nType)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 255, 79, 163 },
        multiline = true,
        args = { 'Starter Pack', message },
    })
end

-- Resolves "[id]" to an online player, or treats the argument as a citizenid.
---@return string|nil citizenid, integer|nil onlineSource, string label
local function resolveTarget(arg)
    if not arg then return nil, nil, 'missing' end
    local id = tonumber(arg)
    if id and GetPlayerName(id) then
        local _, cid = getPlayer(id)
        if not cid then return nil, id, ('player %d is not logged into a character'):format(id) end
        return cid, id, ('%s [%s]'):format(GetPlayerName(id), cid)
    end
    if not id and arg:match('^[%w]+$') and #arg <= 50 then
        local online = exports.qbx_core:GetPlayerByCitizenId(arg)
        return arg, online and online.PlayerData.source or nil, ('citizenid %s'):format(arg)
    end
    return nil, nil, ('no online player with id %s'):format(arg)
end

RegisterCommand(Config.Admin.commands.check, function(src, args)
    if not isAdmin(src) then return reply(src, Msg.noPermission, 'error') end

    local cid, _, label = resolveTarget(args[1])
    if not cid then return reply(src, ('Usage: /%s [id|citizenid] — %s'):format(Config.Admin.commands.check, label), 'error') end

    local row, err = getClaim(cid)
    if err then return reply(src, 'Database error.', 'error') end
    if not row then
        return reply(src, ('%s has NOT claimed a starter pack (eligible).'):format(label), 'inform')
    end

    local stepRows = getStepRows(cid) or {}
    local granted, review = 0, {}
    for key, r in pairs(stepRows) do
        if r.status == 'granted' then granted += 1 else review[#review + 1] = key end
    end

    local pathLabel = Rewards.paths[row.path] and Rewards.paths[row.path].label or row.path
    local msg = ('%s — path: %s | status: %s | steps granted: %d | attempts: %d | chosen: %s%s'):format(
        label, pathLabel, row.status:upper(), granted, row.attempts or 0, fmtDate(row.created_at),
        row.completed_at and (' | completed: ' .. fmtDate(row.completed_at)) or '')
    if #review > 0 or isTrue(row.needs_review) then
        msg = msg .. ('\n⚠ NEEDS REVIEW (outcome unknown, not re-granted): %s'):format(table.concat(review, ', '))
    end
    reply(src, msg, row.status == 'completed' and 'success' or 'warning')
end, false)

RegisterCommand(Config.Admin.commands.reset, function(src, args)
    if not isAdmin(src) then return reply(src, Msg.noPermission, 'error') end

    local cid, online, label = resolveTarget(args[1])
    if not cid then return reply(src, ('Usage: /%s [id|citizenid] — %s'):format(Config.Admin.commands.reset, label), 'error') end

    local row, err = getClaim(cid)
    if err then return reply(src, 'Database error.', 'error') end
    if not row then return reply(src, ('%s has no starter pack claim to reset.'):format(label), 'inform') end

    local resetKey = ('%s:%s'):format(src, cid)
    if args[2] ~= 'confirm' or not pendingResets[resetKey] or os.time() - pendingResets[resetKey] > Config.Admin.resetConfirmWindow then
        pendingResets[resetKey] = os.time()
        return reply(src, ('⚠ WARNING: Resetting %s (path: %s, status: %s) allows them to claim ANOTHER FULL starter pack. Items and money already given will NOT be removed. Type /%s %s confirm within %ds to proceed.'):format(
            label, row.path, row.status, Config.Admin.commands.reset, args[1], Config.Admin.resetConfirmWindow), 'warning')
    end
    pendingResets[resetKey] = nil

    if processingCid[cid] then
        return reply(src, 'That character is being processed right now. Try again in a few seconds.', 'error')
    end

    local ok, committed = pcall(MySQL.transaction.await, {
        { query = 'DELETE FROM `velora_starterpack_rewards` WHERE `citizenid` = ?', values = { cid } },
        { query = 'DELETE FROM `velora_starterpack_claims` WHERE `citizenid` = ?', values = { cid } },
    })
    if not ok or not committed then return reply(src, 'Database error — nothing was reset.', 'error') end

    addHistory(cid, 'reset', row.path, playerLabel(src), ('previous status: %s'):format(row.status))
    logInfo('%s reset starter pack eligibility for %s (was %s / %s).', playerLabel(src), cid, row.path, row.status)
    webhook('Starter pack reset', ('%s reset eligibility for `%s` (was **%s**, %s). Previously granted rewards were NOT removed.'):format(playerLabel(src), cid, row.path, row.status), 15105570)

    reply(src, ('Starter pack eligibility reset for %s. Previously granted items/money were NOT removed.'):format(label), 'success')
    if online then
        sessions[online] = nil
        notify(online, ('Staff have reset your starter pack. Use /%s to choose again.'):format(Config.Command.name), 'inform')
    end
end, false)

RegisterCommand(Config.Admin.commands.give, function(src, args)
    if not isAdmin(src) then return reply(src, Msg.noPermission, 'error') end

    local cid, online, label = resolveTarget(args[1])
    if not cid or not online then
        return reply(src, ('Usage: /%s [id] — the player must be online. %s'):format(Config.Admin.commands.give, label), 'error')
    end

    local payload, errMsg = prepareOpen(online, playerLabel(src))
    if not payload then
        return reply(src, ('Cannot open the menu for %s: %s'):format(label, errMsg), 'error')
    end

    TriggerClientEvent('velora_starterpack:client:open', online, payload)
    addHistory(cid, 'admin_open', nil, playerLabel(src), nil)
    logInfo('%s opened the starter pack menu for %s.', playerLabel(src), label)
    reply(src, ('Opened the starter pack menu for %s.'):format(label), 'success')
end, false)

---------------------------------------------------------------------------
-- Exports for other resources (read-only)
---------------------------------------------------------------------------
exports('GetClaim', function(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    local row = getClaim(citizenid)
    if not row then return nil end
    return { path = row.path, status = row.status, needsReview = isTrue(row.needs_review), completedAt = row.completed_at }
end)

exports('HasClaimed', function(citizenid)
    if type(citizenid) ~= 'string' then return false end
    local row = getClaim(citizenid)
    return row ~= nil and row.status == 'completed'
end)

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------
MySQL.ready(function()
    if Config.Database.autoCreate then
        for _, statement in ipairs(SCHEMA) do
            local _, err = dbCall(MySQL.query.await, statement)
            if err then
                logError('Failed to create database tables. Run sql/install.sql manually.')
                return
            end
        end
    end

    -- Nothing can be mid-processing right after a (re)start, so stale locks are released.
    dbCall(MySQL.update.await, 'UPDATE `velora_starterpack_claims` SET `lock_token` = NULL, `lock_at` = NULL WHERE `lock_token` IS NOT NULL')

    local count = dbCall(MySQL.scalar.await, 'SELECT COUNT(*) FROM `velora_starterpack_claims`')
    if count == nil then
        logError('Database tables are missing. Run sql/install.sql or enable Config.Database.autoCreate.')
        return
    end

    dbReady = true
    logInfo('Database ready (%d claim record(s)).', count)
end)

CreateThread(function()
    -- ox_inventory registers items on start; it is a hard dependency so it is already running.
    validateConfig()
end)

-- Re-validate if ox_inventory is restarted (items may have been added).
AddEventHandler('onResourceStart', function(name)
    if name == 'ox_inventory' then
        SetTimeout(2000, validateConfig)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RESOURCE then return end
    -- In-flight claims are protected by the DB step log; nothing else to clean up.
    for src in pairs(processingSrc) do
        logWarn('Resource stopped while processing a claim for %s — progress is recorded and will resume safely.', playerLabel(src))
    end
end)
