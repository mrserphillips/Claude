-- Velora Jam Co. - orchard harvesting (authoritative stock, rewards and validation)
local Trees = {}     -- id -> { cfg, stock, reserved, restockAt }
local Sessions = {}  -- src -> harvest session

for _, orchard in ipairs(Config.Orchards) do
    for _, cfg in ipairs(orchard.trees) do
        if not Config.Fruits[cfg.fruit] then
            print(('^1[velora_jamco] tree %s uses unknown fruit %s^7'):format(cfg.id, tostring(cfg.fruit)))
        elseif Trees[cfg.id] then
            print(('^1[velora_jamco] duplicate tree id %s^7'):format(cfg.id))
        else
            Trees[cfg.id] = { cfg = cfg, stock = cfg.stock, reserved = 0, restockAt = 0 }
        end
    end
end

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
