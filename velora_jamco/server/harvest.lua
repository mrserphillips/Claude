-- Velora Jam Co. - orchard harvesting (authoritative stock, rewards and validation)
local Trees = {}     -- id -> { cfg, stock, reserved, restockAt }
local Sessions = {}  -- src -> harvest session
local HCFG = Config.Harvest

local function nearestOrchard(coords)
    local best, bestDist = Config.Orchards[1], math.huge
    for _, orchard in ipairs(Config.Orchards) do
        local d = #(vec3(coords.x, coords.y, 0) - vec3(orchard.center.x, orchard.center.y, 0))
        if d < bestDist then best, bestDist = orchard, d end
    end
    return best
end

local function addTree(cfg)
    if not Config.Fruits[cfg.fruit] then
        print(('^1[velora_jamco] tree %s uses unknown fruit %s^7'):format(cfg.id, tostring(cfg.fruit)))
        return
    end
    if Trees[cfg.id] then
        print(('^1[velora_jamco] duplicate tree id %s^7'):format(cfg.id))
        return
    end
    cfg.orchard = cfg.orchard or nearestOrchard(cfg.coords).id
    Trees[cfg.id] = { cfg = cfg, stock = cfg.stock, reserved = 0, restockAt = 0 }
end

-- Defaults for a tree placed in-game with /jamplace
local function placedConfig(row)
    local fruit = row.fruit
    local bush = HCFG.BushFruits[fruit] == true
    local prop = row.prop
    if prop == nil or prop == '' then prop = false end
    return {
        id = 'placed_' .. row.id,
        dbId = row.id,
        fruit = fruit,
        coords = vec3(row.x + 0.0, row.y + 0.0, row.z + 0.0),
        heading = (row.heading or 0) + 0.0,
        prop = prop,
        anim = bush and 'bush' or 'tree',
        stock = HCFG.Placed.stock,
        restock = HCFG.Placed.restock,
        yield = bush and HCFG.Placed.bushYield or HCFG.Placed.yield,
        difficulty = HCFG.FruitDifficulty[fruit] or 'normal',
        placed = true,
    }
end

if HCFG.UseConfigTrees then
    for _, orchard in ipairs(Config.Orchards) do
        for _, cfg in ipairs(orchard.trees) do
            cfg.orchard = orchard.id
            addTree(cfg)
        end
    end
end

-- What clients need to spawn props / target zones
local function clientList()
    local list = {}
    for id, tree in pairs(Trees) do
        local c = tree.cfg
        list[#list + 1] = {
            id = id, fruit = c.fruit, x = c.coords.x, y = c.coords.y, z = c.coords.z, heading = c.heading or 0.0,
            prop = c.prop or false, anim = c.anim, orchard = c.orchard, placed = c.placed or false,
        }
    end
    return list
end

local function broadcast()
    TriggerClientEvent('velora_jamco:client:trees', -1, clientList())
end

-- Orchard summaries for the business UI (centre follows the trees actually placed)
function VJS.orchardSummary()
    local result = {}
    for _, orchard in ipairs(Config.Orchards) do
        local sx, sy, n, fruits, seen = 0, 0, 0, {}, {}
        for _, tree in pairs(Trees) do
            if tree.cfg.orchard == orchard.id then
                sx, sy, n = sx + tree.cfg.coords.x, sy + tree.cfg.coords.y, n + 1
                local f = tree.cfg.fruit
                if not seen[f] then
                    seen[f] = true
                    fruits[#fruits + 1] = { id = f, label = Config.Fruits[f].label, item = Config.Fruits[f].item }
                end
            end
        end
        result[#result + 1] = {
            orchard = orchard, trees = n, fruits = fruits,
            x = n > 0 and sx / n or orchard.center.x, y = n > 0 and sy / n or orchard.center.y,
        }
    end
    return result
end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `velora_jamco_trees` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `fruit` VARCHAR(32) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `heading` FLOAT NOT NULL DEFAULT 0,
        `prop` VARCHAR(64) NULL,
        `created_by` VARCHAR(64) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local rows = MySQL.query.await('SELECT * FROM velora_jamco_trees') or {}
    for _, row in ipairs(rows) do addTree(placedConfig(row)) end
    print(('^5[velora_jamco]^7 %d placed trees loaded'):format(#rows))
    broadcast()
end)

lib.callback.register('velora_jamco:trees:list', function()
    return clientList()
end)

-- ─────────────────────────────────────────────────────────────────────────
-- In-game placement (admins): /jamplace and /jamremove
-- ─────────────────────────────────────────────────────────────────────────
local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command.jamplace')
end

lib.callback.register('velora_jamco:trees:add', function(src, data)
    if not isAdmin(src) then return { ok = false, msg = 'Not allowed.' } end
    if type(data) ~= 'table' or not Config.Fruits[data.fruit] then return { ok = false, msg = 'Unknown fruit.' } end
    local x, y, z, h = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.heading) or 0.0
    if not (x and y and z) then return { ok = false, msg = 'Invalid position.' } end
    if VJS.distance(src, vec3(x, y, z)) > 40.0 then return { ok = false, msg = 'Too far away.' } end
    local prop = nil
    if data.world ~= true then
        prop = HCFG.BushFruits[data.fruit] and HCFG.DefaultProps.bush or HCFG.DefaultProps.tree
        if type(data.prop) == 'string' and data.prop:match('^[%w_]+$') then prop = data.prop end
    end
    local id = MySQL.insert.await('INSERT INTO velora_jamco_trees (fruit, x, y, z, heading, prop, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { data.fruit, x, y, z, h, prop, VJS.getCid(src) })
    if not id then return { ok = false, msg = 'Database error.' } end
    addTree(placedConfig({ id = id, fruit = data.fruit, x = x, y = y, z = z, heading = h, prop = prop }))
    broadcast()
    VJS.log(src, 'tree_placed', { id = id, fruit = data.fruit, world = prop == nil })
    return { ok = true, id = id }
end)

lib.callback.register('velora_jamco:trees:remove', function(src)
    if not isAdmin(src) then return { ok = false, msg = 'Not allowed.' } end
    local best, bestDist = nil, 4.0
    for id, tree in pairs(Trees) do
        if tree.cfg.placed then
            local d = VJS.distance2D(src, tree.cfg.coords)
            if d < bestDist then best, bestDist = id, d end
        end
    end
    if not best then return { ok = false, msg = 'No placed tree within 4m. Trees from config.lua must be removed there.' } end
    local dbId = Trees[best].cfg.dbId
    MySQL.update.await('DELETE FROM velora_jamco_trees WHERE id = ?', { dbId })
    Trees[best] = nil
    for s, session in pairs(Sessions) do
        if session.treeId == best then Sessions[s] = nil end
    end
    broadcast()
    VJS.log(src, 'tree_removed', { id = dbId })
    return { ok = true }
end)

lib.addCommand('jamplace', {
    help = 'Velora Jam Co: place harvestable trees/bushes where you look',
    params = { { name = 'fruit', type = 'string', help = 'orange, apple, lemon, cherry, peach, strawberry, blueberry, blackberry, raspberry, plum', optional = true } },
    restricted = Config.AdminGroup,
}, function(source, args)
    if source <= 0 then return end
    local fruit = args.fruit or 'orange'
    if not Config.Fruits[fruit] then
        return VJS.notify(source, 'Unknown fruit. Use: ' .. table.concat(Config.FruitOrder, ', '), 'error')
    end
    TriggerClientEvent('velora_jamco:client:placeTrees', source, fruit)
end)

lib.addCommand('jamremove', {
    help = 'Velora Jam Co: remove the placed tree nearest to you',
    restricted = Config.AdminGroup,
}, function(source)
    if source <= 0 then return end
    TriggerClientEvent('velora_jamco:client:removeTree', source)
end)

local function refresh(tree)
    if tree.stock <= 0 and tree.restockAt > 0 and os.time() >= tree.restockAt then
        tree.stock = tree.cfg.stock
        tree.restockAt = 0
    end
end

local function available(tree)
    refresh(tree)
    return tree.stock - tree.reserved
end

local function release(src)
    local session = Sessions[src]
    if not session then return end
    Sessions[src] = nil
    local tree = Trees[session.treeId]
    if tree then tree.reserved = math.max(0, tree.reserved - session.reserved) end
end

lib.callback.register('velora_jamco:harvest:start', function(src, treeId)
    local tree = Trees[treeId]
    if not tree then return { ok = false, msg = 'Unknown tree.' } end
    if Sessions[src] then return { ok = false, msg = 'You are already harvesting.' } end
    if Config.RequireShift.harvest and not VJS.onShift(src) then
        return { ok = false, msg = 'Start a shift at Velora Jam Co. first.' }
    end
    local can, why = VJS.canAct(src)
    if not can then return { ok = false, msg = why } end
    if VJS.inVehicle(src) then return { ok = false, msg = 'Get out of the vehicle first.' } end
    if VJS.distance2D(src, tree.cfg.coords) > Config.Harvest.MaxDistance + 2.0 then
        return { ok = false, msg = 'You are too far from the tree.' }
    end

    local left = available(tree)
    if left <= 0 then
        local wait = tree.restockAt > 0 and math.max(1, math.ceil((tree.restockAt - os.time()) / 60)) or 1
        return { ok = false, msg = ('This %s has been picked clean. It will be ready again in about %d min.'):format(tree.cfg.anim == 'bush' and 'bush' or 'tree', wait) }
    end

    local fruit = Config.Fruits[tree.cfg.fruit]
    local hasBasket = VJS.count(src, Config.Supplies.basket.item) > 0
    local yield = math.random(tree.cfg.yield.min, tree.cfg.yield.max)
    local ripe = math.min(left, yield)
    local bonus = hasBasket and Config.Harvest.BasketBonus or 0
    -- the basket bonus is extra capacity, it never takes more than the tree has
    ripe = math.min(left, ripe + bonus)

    local maxReward = ripe + Config.Harvest.PerfectBonus
    if not exports.ox_inventory:CanCarryItem(src, fruit.item, maxReward) then
        return { ok = false, msg = 'Your pockets are too full to carry any more fruit.' }
    end

    local diffId = Config.Harvest.Difficulties[tree.cfg.difficulty] and tree.cfg.difficulty or 'normal'
    local diff = Config.Harvest.Difficulties[diffId]
    local goldenChance = Config.Harvest.GoldenChance + (hasBasket and Config.Harvest.BasketGoldenBonus or 0)

    tree.reserved = tree.reserved + ripe
    local session = {
        token = VJS.token(),
        treeId = treeId,
        reserved = ripe,
        ripe = ripe,
        rotten = math.max(1, VJ.round(ripe * diff.rottenRatio + math.random(0, 1))),
        golden = math.random() < goldenChance,
        started = GetGameTimer(),
        fruit = tree.cfg.fruit,
    }
    Sessions[src] = session

    return {
        ok = true,
        token = session.token,
        fruit = { id = tree.cfg.fruit, label = fruit.label, plural = fruit.plural, item = fruit.item, color = fruit.color },
        ripe = session.ripe,
        rotten = session.rotten,
        golden = session.golden,
        basket = hasBasket,
        difficulty = { id = diffId, label = diff.label, time = diff.time, ripeWindow = diff.ripeWindow, sway = diff.sway, unripeTime = diff.unripeTime },
        kind = tree.cfg.anim,
    }
end)

lib.callback.register('velora_jamco:harvest:finish', function(src, token, result)
    local session = Sessions[src]
    if not session or session.token ~= token or type(result) ~= 'table' then
        return { ok = false, msg = 'This harvest has expired.' }
    end
    if not VJS.lock(src, 'harvest') then return { ok = false, msg = 'Please wait...' } end

    local tree = Trees[session.treeId]
    local elapsed = (GetGameTimer() - session.started) / 1000
    local diff = Config.Harvest.Difficulties[tree.cfg.difficulty] or Config.Harvest.Difficulties.normal

    local picked = math.floor(tonumber(result.picked) or 0)
    local rottenHit = math.floor(tonumber(result.rotten) or 0)
    local goldenPicked = result.golden == true and session.golden

    local reward, perfect, msg = 0, false, nil
    if VJS.distance2D(src, tree.cfg.coords) > Config.Harvest.MaxDistance + 2.0 or VJS.isIncapacitated(src) then
        msg = 'You walked away from the tree.'
    elseif elapsed < 2.0 or elapsed < picked * 0.12 or elapsed > diff.time + 180 then
        msg = 'Harvest could not be verified.'
        VJS.log(src, 'harvest_rejected', { tree = session.treeId, picked = picked, elapsed = elapsed })
    else
        picked = VJ.clamp(picked, 0, session.ripe)
        rottenHit = VJ.clamp(rottenHit, 0, session.rotten + session.ripe)
        reward = math.max(0, picked - rottenHit * Config.Harvest.RottenPenalty)
        perfect = picked == session.ripe and rottenHit == 0
    end

    -- consume only what was actually picked from the tree
    local taken = math.min(picked, session.ripe)
    if msg then taken = 0 end
    tree.reserved = math.max(0, tree.reserved - session.reserved)
    tree.stock = math.max(0, tree.stock - taken)
    if tree.stock <= 0 and tree.restockAt == 0 then tree.restockAt = os.time() + tree.cfg.restock end
    Sessions[src] = nil

    if msg then
        VJS.unlock(src, 'harvest')
        return { ok = false, msg = msg }
    end

    local bonus = perfect and Config.Harvest.PerfectBonus or 0
    local fruit = Config.Fruits[session.fruit]
    local items = { { item = fruit.item, count = reward + bonus } }
    if goldenPicked then items[#items + 1] = { item = Config.Specials.golden.item, count = 1 } end
    local failed = VJS.giveItems(src, items)
    local cid = VJS.getCid(src)
    if #failed > 0 and cid then
        VJS.addPending(cid, 'jam', { items = failed, note = 'harvest' })
    end

    local unlocked = {}
    if cid then
        local stats = VJS.getStats(cid)
        stats.fruit_harvested = stats.fruit_harvested + reward + bonus
        if reward + bonus > 0 then stats.harvested_types[session.fruit] = true end
        if goldenPicked then stats.golden_found = stats.golden_found + 1 end
        VJS.saveStats(cid)
        unlocked = VJS.checkAchievements(src, cid)
    end

    VJS.log(src, 'harvest', { tree = session.treeId, fruit = session.fruit, amount = reward + bonus, golden = goldenPicked or false })
    VJS.unlock(src, 'harvest')
    return {
        ok = true,
        amount = reward + bonus,
        picked = picked,
        rotten = rottenHit,
        bonus = bonus,
        perfect = perfect,
        golden = goldenPicked or false,
        overflow = #failed > 0,
        label = fruit.plural,
        achievements = unlocked,
    }
end)

lib.callback.register('velora_jamco:harvest:cancel', function(src, token)
    local session = Sessions[src]
    if session and session.token == token then release(src) end
    return true
end)

AddEventHandler('playerDropped', function()
    release(source)
end)

-- Admin: instantly restock every tree
lib.addCommand('jamreset', {
    help = 'Velora Jam Co: restock every orchard tree',
    restricted = Config.AdminGroup,
}, function(source)
    for _, tree in pairs(Trees) do
        tree.stock = tree.cfg.stock
        tree.restockAt = 0
    end
    if source > 0 then VJS.notify(source, 'All orchard trees restocked.', 'success') end
    print('[velora_jamco] all trees restocked')
end)
