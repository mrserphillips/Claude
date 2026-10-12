-- Velora Jam Co. - server core: player helpers, inventory, money, persistence, logging
VJS = {}

local ox = exports.ox_inventory

-- ─────────────────────────────────────────────────────────────────────────
-- Recipe index (server only)
-- ─────────────────────────────────────────────────────────────────────────
VJS.Recipes = {}
VJS.RecipeByKey = {}
VJS.RecipeList = {}

function VJS.recipeKey(fruits, special)
    local list = {}
    for i = 1, #fruits do list[i] = fruits[i] end
    table.sort(list)
    return table.concat(list, '+') .. '|' .. (special or '')
end

do
    for i = 1, #Recipes do
        local r = Recipes[i]
        local valid = type(r.id) == 'string' and type(r.fruits) == 'table' and #r.fruits >= 1 and #r.fruits <= 3
        if valid then
            for _, f in ipairs(r.fruits) do
                if not Config.Fruits[f] then
                    print(('^1[velora_jamco] recipe %s uses unknown fruit "%s" - skipped^7'):format(r.id, f))
                    valid = false
                end
            end
            if r.special and not Config.Specials[r.special] then
                print(('^1[velora_jamco] recipe %s uses unknown special "%s" - skipped^7'):format(r.id, r.special))
                valid = false
            end
            if not Config.Rarities[r.rarity] then r.rarity = 'common' end
        end
        if valid then
            local key = VJS.recipeKey(r.fruits, r.special)
            if VJS.RecipeByKey[key] then
                print(('^1[velora_jamco] recipes %s and %s use identical ingredients - %s skipped^7'):format(VJS.RecipeByKey[key].id, r.id, r.id))
            elseif VJS.Recipes[r.id] then
                print(('^1[velora_jamco] duplicate recipe id %s - skipped^7'):format(r.id))
            else
                r.key = key
                r.value = r.value or VJ.rarity(r.rarity).value
                VJS.RecipeByKey[key] = r
                VJS.Recipes[r.id] = r
                VJS.RecipeList[#VJS.RecipeList + 1] = r
                r.index = #VJS.RecipeList
            end
        end
    end
    ExperimentalRecipe.value = ExperimentalRecipe.value or VJ.rarity('experimental').value
    VJS.Recipes[ExperimentalRecipe.id] = ExperimentalRecipe
    print(('^5[velora_jamco]^7 loaded %d recipes'):format(#VJS.RecipeList))
    local manifestVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'
    print(('^5[velora_jamco]^7 version %s running from %s'):format(VJ.VERSION, GetResourcePath(GetCurrentResourceName())))
    if manifestVersion ~= VJ.VERSION then
        for _ = 1, 3 do
            print(('^1[velora_jamco] fxmanifest.lua is STALE (server has v%s, files are v%s). Run "refresh" then "ensure %s" in the console - until then new UI files and artwork are not sent to players.^7')
                :format(manifestVersion, VJ.VERSION, GetCurrentResourceName()))
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- Player helpers (qbx_core)
-- ─────────────────────────────────────────────────────────────────────────
function VJS.getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function VJS.getCid(src)
    local player = VJS.getPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

function VJS.getName(src)
    local player = VJS.getPlayer(src)
    if not player then return 'Unknown' end
    local info = player.PlayerData.charinfo or {}
    return ('%s %s'):format(info.firstname or 'Unknown', info.lastname or '')
end

function VJS.isIncapacitated(src)
    local player = VJS.getPlayer(src)
    if not player then return true end
    local meta = player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand then return true end
    local ped = GetPlayerPed(src)
    return ped == 0 or GetEntityHealth(ped) <= 0
end

function VJS.inVehicle(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
end

function VJS.coords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function VJS.distance(src, target)
    local c = VJS.coords(src)
    if not c then return math.huge end
    return #(c - vec3(target.x, target.y, target.z))
end

-- Horizontal distance (tree props snap to the ground, so config Z may differ a little)
function VJS.distance2D(src, target)
    local c = VJS.coords(src)
    if not c then return math.huge end
    local dx, dy, dz = c.x - target.x, c.y - target.y, c.z - target.z
    if math.abs(dz) > 12.0 then return math.huge end
    return math.sqrt(dx * dx + dy * dy)
end

function VJS.notify(src, description, ntype, title, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or Config.BusinessName,
        description = description,
        type = ntype or 'inform',
        duration = duration or 5000,
        icon = 'jar',
        iconColor = '#f06aa6',
    })
end

function VJS.token()
    return ('%x%x%x'):format(math.random(0x10000000, 0x7fffffff), GetGameTimer(), math.random(0x1000, 0xffff))
end

-- ─────────────────────────────────────────────────────────────────────────
-- Money (current qbx_core exports, with a safe fallback for older builds)
-- ─────────────────────────────────────────────────────────────────────────
function VJS.getMoney(src, account)
    local ok, res = pcall(function() return exports.qbx_core:GetMoney(src, account) end)
    if ok and type(res) == 'number' then return res end
    local player = VJS.getPlayer(src)
    return player and player.PlayerData.money and player.PlayerData.money[account] or 0
end

function VJS.addMoney(src, account, amount, reason, kind)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    local ok, res = pcall(function() return exports.qbx_core:AddMoney(src, account, amount, reason) end)
    local success
    if ok then
        success = res ~= false
    else
        local player = VJS.getPlayer(src)
        success = player and player.Functions.AddMoney(account, amount, reason) or false
    end
    if success then pcall(Config.OnMoneyTransaction, src, kind or 'refund', account, amount, reason) end
    return success
end

function VJS.removeMoney(src, account, amount, reason, kind)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if VJS.getMoney(src, account) < amount then return false end
    local ok, res = pcall(function() return exports.qbx_core:RemoveMoney(src, account, amount, reason) end)
    local success
    if ok then
        success = res ~= false
    else
        local player = VJS.getPlayer(src)
        success = player and player.Functions.RemoveMoney(account, amount, reason) or false
    end
    if success then pcall(Config.OnMoneyTransaction, src, kind or 'deposit', account, amount, reason) end
    return success
end

-- ─────────────────────────────────────────────────────────────────────────
-- Inventory helpers (ox_inventory)
-- ─────────────────────────────────────────────────────────────────────────
function VJS.count(src, item)
    return ox:GetItemCount(src, item) or 0
end

function VJS.counts(src, items)
    local result = {}
    local found = ox:Search(src, 'count', items)
    for _, name in ipairs(items) do
        result[name] = type(found) == 'table' and (found[name] or 0) or 0
    end
    return result
end

-- Removes every {item, count} or nothing at all
function VJS.takeItems(src, list)
    for _, entry in ipairs(list) do
        if VJS.count(src, entry.item) < entry.count then return false, entry.item end
    end
    local taken = {}
    for _, entry in ipairs(list) do
        if ox:RemoveItem(src, entry.item, entry.count) then
            taken[#taken + 1] = entry
        else
            for _, back in ipairs(taken) do ox:AddItem(src, back.item, back.count) end
            return false, entry.item
        end
    end
    return true
end

-- Gives every {item, count, metadata}; returns the entries that did not fit
function VJS.giveItems(src, list)
    local failed = {}
    for _, entry in ipairs(list) do
        if entry.count > 0 then
            local ok = ox:CanCarryItem(src, entry.item, entry.count, entry.metadata) and ox:AddItem(src, entry.item, entry.count, entry.metadata)
            if not ok then failed[#failed + 1] = entry end
        end
    end
    return failed
end

-- ─────────────────────────────────────────────────────────────────────────
-- Logging
-- ─────────────────────────────────────────────────────────────────────────
function VJS.log(src, action, data)
    local cid = src and VJS.getCid(src) or 'system'
    local name = src and VJS.getName(src) or 'system'
    local encoded = json.encode(data or {})
    if Config.Logging.console then
        print(('^5[velora_jamco]^7 [%s] %s (%s / %s) %s'):format(action, name, cid, tostring(src), encoded))
    end
    if Config.Logging.database then
        MySQL.insert('INSERT INTO velora_jamco_logs (citizenid, action, data) VALUES (?, ?, ?)', { cid, action, encoded })
    end
    if SVConfig.Webhook and SVConfig.Webhook ~= '' then
        PerformHttpRequest(SVConfig.Webhook, function() end, 'POST', json.encode({
            username = SVConfig.WebhookName,
            embeds = { {
                title = action,
                color = 15755942,
                description = ('**%s** (%s)\n```json\n%s\n```'):format(name, cid, encoded),
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- Database
-- ─────────────────────────────────────────────────────────────────────────
VJS.DBReady = false

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `velora_jamco_players` (
        `citizenid` VARCHAR(64) NOT NULL,
        `stats` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `velora_jamco_recipes` (
        `citizenid` VARCHAR(64) NOT NULL,
        `recipe_id` VARCHAR(64) NOT NULL,
        `best_quality` INT NOT NULL DEFAULT 0,
        `crafted` INT NOT NULL DEFAULT 0,
        `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `recipe_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `velora_jamco_pending` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `payload` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `velora_jamco_logs` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `action` VARCHAR(48) NOT NULL,
        `data` LONGTEXT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `action` (`action`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    VJS.DBReady = true
    VJ.debug('database ready')
end)

-- Stats --------------------------------------------------------------------
local Stats = {}        -- cid -> stats
local Discoveries = {}  -- cid -> { [recipeId] = { best, crafted } }

local function defaultStats()
    return {
        jars_crafted = 0, batches = 0, jars_sold = 0, total_earned = 0, best_sale = 0,
        fruit_harvested = 0, golden_found = 0, perfect_batches = 0, experiments = 0,
        counters_won = 0, legendary_crafted = 0, customers = 0,
        harvested_types = {}, achievements = {},
    }
end

function VJS.getStats(cid)
    if Stats[cid] then return Stats[cid] end
    local stats = defaultStats()
    local row = MySQL.scalar.await('SELECT stats FROM velora_jamco_players WHERE citizenid = ?', { cid })
    if row then
        local decoded = json.decode(row)
        if type(decoded) == 'table' then
            for k, v in pairs(decoded) do stats[k] = v end
        end
    end
    Stats[cid] = stats
    return stats
end

function VJS.saveStats(cid)
    local stats = Stats[cid]
    if not stats then return end
    MySQL.prepare('INSERT INTO velora_jamco_players (citizenid, stats) VALUES (?, ?) ON DUPLICATE KEY UPDATE stats = VALUES(stats)',
        { cid, json.encode(stats) })
end

function VJS.getDiscoveries(cid)
    if Discoveries[cid] then return Discoveries[cid] end
    local list = {}
    local rows = MySQL.query.await('SELECT recipe_id, best_quality, crafted FROM velora_jamco_recipes WHERE citizenid = ?', { cid }) or {}
    for _, row in ipairs(rows) do
        list[row.recipe_id] = { best = row.best_quality, crafted = row.crafted }
    end
    Discoveries[cid] = list
    return list
end

function VJS.discoveredCount(cid)
    local count = 0
    for id in pairs(VJS.getDiscoveries(cid)) do
        if VJS.Recipes[id] and id ~= ExperimentalRecipe.id then count = count + 1 end
    end
    return count
end

-- Records a crafted batch; returns true when the recipe is new for this character
function VJS.recordRecipe(cid, recipeId, quality, jars)
    local list = VJS.getDiscoveries(cid)
    local entry = list[recipeId]
    local isNew = entry == nil
    if isNew then
        entry = { best = quality, crafted = jars }
        list[recipeId] = entry
    else
        entry.best = math.max(entry.best, quality)
        entry.crafted = entry.crafted + jars
    end
    MySQL.prepare([[INSERT INTO velora_jamco_recipes (citizenid, recipe_id, best_quality, crafted) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE best_quality = GREATEST(best_quality, VALUES(best_quality)), crafted = crafted + VALUES(crafted)]],
        { cid, recipeId, quality, jars })
    return isNew
end

-- Achievements ---------------------------------------------------------------
local AchievementChecks = {
    first_batch = function(s) return s.jars_crafted >= 1 end,
    orchard_explorer = function(s)
        for _, fruit in ipairs(Config.FruitOrder) do
            if not s.harvested_types[fruit] then return false end
        end
        return true
    end,
    golden_touch = function(s) return s.golden_found >= 1 end,
    mad_scientist = function(s) return s.experiments >= 10 end,
    perfectionist = function(s) return s.perfect_batches >= 1 end,
    smooth_talker = function(s) return s.counters_won >= 10 end,
    master_jam_maker = function(_, discovered) return discovered >= 25 end,
    legendary_preserver = function(s) return s.legendary_crafted >= 1 end,
    jam_tycoon = function(s) return s.total_earned >= 25000 end,
    veloras_finest = function(_, discovered) return discovered >= #VJS.RecipeList end,
}

function VJS.checkAchievements(src, cid)
    local stats = VJS.getStats(cid)
    local discovered = VJS.discoveredCount(cid)
    local unlocked = {}
    for _, ach in ipairs(Config.Achievements) do
        local check = AchievementChecks[ach.id]
        if check and not stats.achievements[ach.id] and check(stats, discovered) then
            stats.achievements[ach.id] = os.time()
            unlocked[#unlocked + 1] = { id = ach.id, label = ach.label, description = ach.description }
        end
    end
    if #unlocked > 0 then
        VJS.saveStats(cid)
        TriggerClientEvent('velora_jamco:client:achievements', src, unlocked)
        VJS.log(src, 'achievement', { unlocked = unlocked })
    end
    return unlocked
end

function VJS.achievementList(cid)
    local stats = VJS.getStats(cid)
    local list = {}
    for _, ach in ipairs(Config.Achievements) do
        list[#list + 1] = { id = ach.id, label = ach.label, description = ach.description, unlocked = stats.achievements[ach.id] ~= nil }
    end
    return list
end

-- Recipe book payload: undiscovered recipes never include names or ingredients
function VJS.recipeBook(cid)
    local discoveries = VJS.getDiscoveries(cid)
    local list, found = {}, 0
    for _, r in ipairs(VJS.RecipeList) do
        local d = discoveries[r.id]
        if d then
            found = found + 1
            local fruits = {}
            for _, f in ipairs(r.fruits) do fruits[#fruits + 1] = { id = f, label = Config.Fruits[f].label, item = Config.Fruits[f].item } end
            local special = r.special and { id = r.special, label = Config.Specials[r.special].label, item = Config.Specials[r.special].item } or nil
            list[#list + 1] = {
                index = r.index, discovered = true, id = r.id, label = r.label, rarity = r.rarity,
                description = r.description, image = r.image, color = r.color,
                fruits = fruits, special = special, best = d.best, crafted = d.crafted,
                priceMin = math.floor(r.value * Config.QualityTiers[#Config.QualityTiers].mult),
                priceMax = math.floor(r.value * Config.QualityTiers[1].mult),
            }
        else
            list[#list + 1] = { index = r.index, discovered = false }
        end
    end
    local exp = discoveries[ExperimentalRecipe.id]
    return {
        recipes = list,
        found = found,
        total = #VJS.RecipeList,
        percent = #VJS.RecipeList > 0 and math.floor(found / #VJS.RecipeList * 100) or 0,
        experiments = exp and exp.crafted or 0,
    }
end

-- ─────────────────────────────────────────────────────────────────────────
-- Pending deliveries (crash / restart recovery and the cooling rack)
-- kind: 'refund' (items owed back), 'money' (account money owed), 'jam' (cooling rack)
-- ─────────────────────────────────────────────────────────────────────────
function VJS.addPending(cid, kind, payload)
    return MySQL.insert.await('INSERT INTO velora_jamco_pending (citizenid, kind, payload) VALUES (?, ?, ?)',
        { cid, kind, json.encode(payload) })
end

function VJS.removePending(id)
    return MySQL.update.await('DELETE FROM velora_jamco_pending WHERE id = ?', { id })
end

function VJS.getPending(cid, kind)
    local rows = MySQL.query.await('SELECT id, kind, payload FROM velora_jamco_pending WHERE citizenid = ? AND kind = ?', { cid, kind }) or {}
    for _, row in ipairs(rows) do row.payload = json.decode(row.payload) or {} end
    return rows
end

-- Rows still marked as in-progress belong to sessions that cannot continue (crash/restart).
VJS.LiveSessionRows = {}  -- pending id -> true while its crafting session is running

local Ready = {}

local function processPending(src)
    local cid = VJS.getCid(src)
    if not cid then return end
    local refunded = 0
    for _, row in ipairs(VJS.getPending(cid, 'refund')) do
        if not VJS.LiveSessionRows[row.id] then
            -- delete first so a refund can never be paid twice
            if VJS.removePending(row.id) > 0 then
                local failed = VJS.giveItems(src, row.payload.items or {})
                if #failed > 0 then VJS.addPending(cid, 'jam', { items = failed, note = 'refund' }) end
                refunded = refunded + 1
                VJS.log(src, 'recovery_refund', row.payload)
            end
        end
    end
    for _, row in ipairs(VJS.getPending(cid, 'money')) do
        if VJS.removePending(row.id) > 0 then
            VJS.addMoney(src, row.payload.account or 'bank', row.payload.amount or 0, row.payload.reason or 'velora_jamco_refund', 'refund')
            refunded = refunded + 1
            VJS.log(src, 'recovery_money', row.payload)
        end
    end
    if refunded > 0 then
        VJS.notify(src, 'An unfinished jam session was recovered - your ingredients/deposit have been returned.', 'success')
    end
end

RegisterNetEvent('velora_jamco:server:ready', function()
    local src = source
    if Ready[src] then return end
    local cid = VJS.getCid(src)
    if not cid then return end
    while not VJS.DBReady do Wait(250) end
    Ready[src] = cid
    VJS.getStats(cid)
    VJS.getDiscoveries(cid)
    processPending(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cid = Ready[src]
    Ready[src] = nil
    if cid then
        -- keep memory small; data is persisted on every change
        SetTimeout(5000, function()
            for _, id in pairs(Ready) do
                if id == cid then return end
            end
            Stats[cid] = nil
            Discoveries[cid] = nil
        end)
    end
end)

-- qbx_core logout (character switch) clears the ready flag so the next character loads cleanly
RegisterNetEvent('qbx_core:server:onPlayerUnload', function() Ready[source] = nil end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) Ready[src] = nil end)

-- ─────────────────────────────────────────────────────────────────────────
-- Shared validation
-- ─────────────────────────────────────────────────────────────────────────
function VJS.canAct(src)
    if VJS.isIncapacitated(src) then return false, 'You cannot do that right now.' end
    return true
end

-- Simple per-player mutex so double clicks / repeated callbacks cannot overlap
local Locks = {}
function VJS.lock(src, name)
    local key = src .. ':' .. name
    if Locks[key] then return false end
    Locks[key] = true
    return true
end

function VJS.unlock(src, name)
    Locks[src .. ':' .. name] = nil
end

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for key in pairs(Locks) do
        if key:sub(1, #prefix) == prefix then Locks[key] = nil end
    end
end)

-- Player sees their own statistics
lib.callback.register('velora_jamco:stats', function(src)
    local cid = VJS.getCid(src)
    if not cid then return nil end
    local stats = VJS.getStats(cid)
    return {
        stats = stats,
        achievements = VJS.achievementList(cid),
        discovered = VJS.discoveredCount(cid),
        total = #VJS.RecipeList,
    }
end)

lib.callback.register('velora_jamco:book', function(src)
    local cid = VJS.getCid(src)
    if not cid then return nil end
    return VJS.recipeBook(cid)
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Admin helpers
-- ─────────────────────────────────────────────────────────────────────────
lib.addCommand('jamcoords', {
    help = 'Velora Jam Co: copy your position as vec4',
    restricted = Config.AdminGroup,
}, function(source)
    if source > 0 then TriggerClientEvent('velora_jamco:client:copyCoords', source, 'vec4') end
end)

lib.addCommand('jamtree', {
    help = 'Velora Jam Co: copy a config.lua tree entry at your position',
    params = { { name = 'fruit', type = 'string', help = 'orange, apple, lemon, cherry, peach, strawberry, blueberry, blackberry, raspberry, plum' } },
    restricted = Config.AdminGroup,
}, function(source, args)
    if source <= 0 then return end
    if not Config.Fruits[args.fruit] then
        return VJS.notify(source, 'Unknown fruit. Use: ' .. table.concat(Config.FruitOrder, ', '), 'error')
    end
    TriggerClientEvent('velora_jamco:client:copyCoords', source, 'tree', args.fruit)
end)

lib.callback.register('velora_jamco:version', function()
    local res = GetCurrentResourceName()
    return { version = VJ.VERSION, manifest = GetResourceMetadata(res, 'version', 0), path = GetResourcePath(res), name = res }
end)
