-- Velora Jam Co. - jam kitchen: ingredients, minigame validation, quality, discovery
local Sessions = {}   -- src -> crafting session
local STAGES = { 'prepare', 'heat', 'stir', 'fill', 'seal' }
-- the fastest a real player can complete each stage (seconds)
local MIN_SECONDS = { prepare = 2.5, heat = 5.0, stir = 3.0, fill = 0.8, seal = 1.0 }

local function nearKitchen(src)
    for _, kitchen in ipairs(Config.Kitchens) do
        if VJS.distance(src, kitchen.coords) <= kitchen.maxDistance + 1.5 then return kitchen end
    end
    return nil
end

local function num(v, lo, hi)
    v = tonumber(v) or 0
    if v ~= v then v = 0 end -- NaN
    return VJ.clamp(v, lo, hi)
end

-- ─────────────────────────────────────────────────────────────────────────
-- Ingredients
-- ─────────────────────────────────────────────────────────────────────────
local function parseIngredients(data)
    if type(data) ~= 'table' or type(data.fruits) ~= 'table' then return nil, 'Choose some fruit first.' end
    local fruits, seen = {}, {}
    for _, id in ipairs(data.fruits) do
        if type(id) ~= 'string' or not Config.Fruits[id] then return nil, 'Unknown fruit.' end
        if seen[id] then return nil, 'Each fruit can only be used once in a mix.' end
        seen[id] = true
        fruits[#fruits + 1] = id
    end
    if #fruits < 1 then return nil, 'Add at least one fruit.' end
    if #fruits > 3 then return nil, 'A mix can contain at most three fruits.' end

    local special = nil
    if data.special ~= nil and data.special ~= false and data.special ~= '' then
        if type(data.special) ~= 'string' or not Config.Specials[data.special] then return nil, 'Unknown special ingredient.' end
        special = data.special
    end

    local jars = math.floor(tonumber(data.jars) or 1)
    if jars < 1 or jars > Config.Crafting.MaxJarsPerBatch then return nil, 'Invalid batch size.' end

    return { fruits = fruits, special = special, jars = jars, pectin = data.pectin == true }
end

local function requirements(parsed)
    local list = {}
    local perJar = Config.Crafting.FruitPerJar[#parsed.fruits] or 2
    for _, id in ipairs(parsed.fruits) do
        list[#list + 1] = { item = Config.Fruits[id].item, count = perJar * parsed.jars, label = Config.Fruits[id].label, kind = 'fruit' }
    end
    if parsed.special then
        local s = Config.Specials[parsed.special]
        list[#list + 1] = { item = s.item, count = Config.Crafting.SpecialPerBatch, label = s.label, kind = 'special' }
    end
    list[#list + 1] = { item = Config.Supplies.sugar.item, count = Config.Crafting.SugarPerJar * parsed.jars, label = Config.Supplies.sugar.label, kind = 'sugar' }
    list[#list + 1] = { item = Config.Supplies.jar.item, count = parsed.jars, label = Config.Supplies.jar.label, kind = 'jar' }
    list[#list + 1] = { item = Config.Supplies.lid.item, count = parsed.jars, label = Config.Supplies.lid.label, kind = 'lid' }
    if parsed.pectin then
        list[#list + 1] = { item = Config.Supplies.pectin.item, count = 1, label = Config.Supplies.pectin.label, kind = 'pectin' }
    end
    return list
end

local function refundFor(session, cancelledEarly)
    if cancelledEarly and Config.Crafting.RefundOnCancelBeforeCooking then return session.reqs end
    local list = {}
    for _, entry in ipairs(session.reqs) do
        if entry.kind == 'jar' or entry.kind == 'lid' then list[#list + 1] = { item = entry.item, count = entry.count } end
    end
    return list
end

local function rackList(cid)
    local list = {}
    for _, row in ipairs(VJS.getPending(cid, 'jam')) do
        local total, label = 0, nil
        for _, entry in ipairs(row.payload.items or {}) do
            total = total + entry.count
            label = label or (entry.metadata and entry.metadata.label) or entry.item
        end
        list[#list + 1] = { id = row.id, label = label or 'Items', count = total, note = row.payload.note }
    end
    return list
end

-- ─────────────────────────────────────────────────────────────────────────
-- Kitchen data & preview
-- ─────────────────────────────────────────────────────────────────────────
lib.callback.register('velora_jamco:kitchen:getData', function(src)
    local cid = VJS.getCid(src)
    if not cid then return nil end
    if not nearKitchen(src) then return { error = 'You need to be at the jam kitchen.' } end

    local fruits, specials = {}, {}
    for _, id in ipairs(Config.FruitOrder) do
        local f = Config.Fruits[id]
        fruits[#fruits + 1] = { id = id, label = f.label, plural = f.plural, item = f.item, color = f.color }
    end
    for _, id in ipairs(Config.SpecialOrder) do
        local s = Config.Specials[id]
        specials[#specials + 1] = { id = id, label = s.label, item = s.item, color = s.color }
    end

    return {
        counts = VJS.counts(src, VJ.allItemNames()),
        fruits = fruits,
        specials = specials,
        supplies = Config.Supplies,
        rules = {
            maxJars = Config.Crafting.MaxJarsPerBatch,
            -- string keys so the table serialises as a JSON object, not an array
            fruitPerJar = {
                ['1'] = Config.Crafting.FruitPerJar[1],
                ['2'] = Config.Crafting.FruitPerJar[2],
                ['3'] = Config.Crafting.FruitPerJar[3],
            },
            sugarPerJar = Config.Crafting.SugarPerJar,
            specialPerBatch = Config.Crafting.SpecialPerBatch,
            requireBowl = Config.Crafting.RequireMixingBowl,
            pectinBonus = Config.Crafting.PectinQualityBonus,
        },
        book = VJS.recipeBook(cid),
        rack = rackList(cid),
        stats = VJS.getStats(cid),
        achievements = VJS.achievementList(cid),
        active = Sessions[src] ~= nil,
    }
end)

lib.callback.register('velora_jamco:kitchen:preview', function(src, data)
    local cid = VJS.getCid(src)
    if not cid then return nil end
    local parsed, err = parseIngredients(data)
    if not parsed then return { ok = false, msg = err } end

    local recipe = VJS.RecipeByKey[VJS.recipeKey(parsed.fruits, parsed.special)]
    local discoveries = VJS.getDiscoveries(cid)
    local reqs = requirements(parsed)
    local counts = VJS.counts(src, (function()
        local items = {}
        for _, r in ipairs(reqs) do items[#items + 1] = r.item end
        return items
    end)())
    for _, r in ipairs(reqs) do r.have = counts[r.item] or 0 end

    local preview
    if recipe and discoveries[recipe.id] then
        preview = {
            known = true, label = recipe.label, rarity = recipe.rarity, image = recipe.image,
            color = recipe.color, description = recipe.description, best = discoveries[recipe.id].best,
        }
    else
        preview = { known = false, promising = recipe ~= nil and Config.Discovery.HintValidCombos or false }
    end
    return { ok = true, preview = preview, requirements = reqs }
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Stage evaluators: the server turns raw minigame telemetry into scores
-- ─────────────────────────────────────────────────────────────────────────
local Evaluate = {}

function Evaluate.prepare(p, data, elapsed)
    local hits = math.floor(num(data.hits, 0, p.targets))
    local perfects = math.floor(num(data.perfects, 0, hits))
    local misses = math.floor(num(data.misses, 0, 99))
    if elapsed < p.targets * 0.3 then return 0, { implausible = true } end
    local score = (hits / p.targets) * 85 + (perfects / p.targets) * 15 - misses * 2
    return VJ.clamp(score, 0, 100), { hits = hits, perfects = perfects }
end

function Evaluate.heat(p, data, elapsed)
    local inBand = num(data.inBand, 0, 600000)
    local hot = num(data.hot, 0, 600000)
    local cold = num(data.cold, 0, 600000)
    local warm = num(data.warm, 0, 600000)
    local total = inBand + hot + cold + warm
    local cooked = inBand + hot + cold * 0.3
    if total > elapsed * 1000 + 2000 or cooked < p.cookSeconds * 1000 * 0.85 then
        return 0, { implausible = true }
    end
    local burned = hot >= p.burnSeconds * 1000
    local score = 100 * inBand / math.max(1, inBand + hot + cold)
    if burned then score = score - 25 end
    return VJ.clamp(score, 0, 100), { burned = burned }
end

function Evaluate.stir(p, data, elapsed)
    local revs = num(data.revs, 0, 500)
    local smooth = num(data.smooth, 0, 1)
    local avgBurn = num(data.avgBurn, 0, 1)
    local maxBurn = num(data.maxBurn, 0, 1)
    if revs < p.revolutions - 0.5 or revs > elapsed * 3.4 + 1 then return 0, { implausible = true } end
    local burned = maxBurn >= 0.999
    local score = 100 * (0.55 * smooth + 0.45 * (1 - avgBurn))
    if burned then score = score - 25 end
    return VJ.clamp(score, 0, 100), { burned = burned }
end

function Evaluate.fill(p, data)
    local fill = num(data.fill, 0, 130)
    local score, perfect = 0, false
    if fill >= p.perfectMin and fill <= p.perfectMax then
        score, perfect = 100, true
    elseif fill >= p.idealMin and fill <= p.idealMax then
        score = 88
    elseif fill < p.idealMin then
        score = 88 - (p.idealMin - fill) * 3.2
    else
        score = 88 - (fill - p.idealMax) * 4.5
    end
    return VJ.clamp(score, 0, 100), { perfect = perfect, wasted = fill > p.waste, fill = fill }
end

function Evaluate.seal(p, data, elapsed)
    if type(data.offsets) ~= 'table' or #data.offsets ~= p.attempts then return 0, { implausible = true } end
    if elapsed < p.attempts * 0.35 then return 0, { implausible = true } end
    local half = p.zone / 2
    local total = 0
    for i = 1, p.attempts do
        local off = math.abs(num(data.offsets[i], -360, 360))
        local s
        if off <= p.perfect then
            s = 100
        elseif off <= half then
            s = 100 - (off - p.perfect) / math.max(1, half - p.perfect) * 35
        else
            s = math.max(0, 50 - (off - half) * 2)
        end
        total = total + s
    end
    return VJ.clamp(total / p.attempts, 0, 100), {}
end

-- ─────────────────────────────────────────────────────────────────────────
-- Session lifecycle
-- ─────────────────────────────────────────────────────────────────────────
local function closeSession(src, session)
    Sessions[src] = nil
    if session.pendingId then
        VJS.LiveSessionRows[session.pendingId] = nil
        return VJS.removePending(session.pendingId) > 0
    end
    return true
end

local function cancelSession(src, session, reason)
    local early = session.stage == 1
    local refund = refundFor(session, early)
    if closeSession(src, session) and #refund > 0 then
        local failed = VJS.giveItems(src, refund)
        if #failed > 0 then VJS.addPending(session.cid, 'jam', { items = failed, note = 'refund' }) end
    end
    VJS.log(src, 'craft_cancel', { reason = reason, stage = STAGES[session.stage], refunded = refund })
    return early
end

local function finishSession(src, session)
    local recipe = session.recipe
    local weights = Config.QualityWeights
    local quality = 0
    for _, stage in ipairs(STAGES) do
        quality = quality + (session.scores[stage] or 0) * (weights[stage] or 0)
    end
    if session.parsed.pectin then quality = quality + Config.Crafting.PectinQualityBonus end

    local notes = {}
    local jars = session.parsed.jars
    if session.flags.burned then
        quality = math.min(quality, 35)
        notes[#notes + 1] = 'The jam caught on the bottom of the pot and tastes scorched.'
    end
    if session.flags.wasted then
        if jars > 1 then
            jars = jars - 1
            notes[#notes + 1] = 'Overfilling wasted enough jam for one jar.'
        else
            quality = quality - 10
            notes[#notes + 1] = 'Jam spilled over the rim of the jar.'
        end
    end
    if session.flags.perfectFill then notes[#notes + 1] = 'Perfect fill level!' end
    quality = math.floor(VJ.clamp(quality, 0, 100))
    local tier = VJ.qualityTier(quality)
    local rarity = VJ.rarity(recipe.rarity)

    local fruitLabels = {}
    for _, id in ipairs(session.parsed.fruits) do fruitLabels[#fruitLabels + 1] = Config.Fruits[id].label end
    if session.parsed.special then fruitLabels[#fruitLabels + 1] = Config.Specials[session.parsed.special].label end

    local label = recipe.label
    if recipe.id == ExperimentalRecipe.id then
        label = ('Experimental %s'):format(table.concat(fruitLabels, ' & '))
    end

    local maker = VJS.getName(src)
    local batch = ('VJ-%s-%s'):format(os.date('%y%m%d'), session.token:sub(-6):upper())
    local metadata = {
        label = label,
        recipe = recipe.id,
        rarity = recipe.rarity,
        quality = quality,
        tier = tier.label,
        batch = batch,
        maker = maker,
        made = os.date('%d/%m/%Y'),
        fruits = table.concat(session.parsed.fruits, ','),
        imageurl = Config.JamImageUrl:format(recipe.image),
        description = ('%s • %s\nQuality %d%% (%s)\nIngredients: %s\nBatch %s • Made by %s'):format(
            rarity.label, label, quality, tier.label, table.concat(fruitLabels, ', '), batch, maker),
    }

    if not closeSession(src, session) then
        -- the row was already consumed elsewhere (should never happen) - do not hand out a duplicate
        return { ok = false, msg = 'This batch was already completed.' }
    end

    local failed = VJS.giveItems(src, { { item = Config.JamItem, count = jars, metadata = metadata } })
    local rack = #failed > 0
    if rack then VJS.addPending(session.cid, 'jam', { items = failed, note = 'batch' }) end

    local cid = session.cid
    local stats = VJS.getStats(cid)
    stats.jars_crafted = stats.jars_crafted + jars
    stats.batches = stats.batches + 1
    if quality >= 95 then stats.perfect_batches = stats.perfect_batches + 1 end
    if recipe.id == ExperimentalRecipe.id then stats.experiments = stats.experiments + 1 end
    if recipe.rarity == 'legendary' then stats.legendary_crafted = stats.legendary_crafted + 1 end
    VJS.saveStats(cid)

    local isNew = VJS.recordRecipe(cid, recipe.id, quality, jars) and recipe.id ~= ExperimentalRecipe.id
    local unlocked = VJS.checkAchievements(src, cid)

    VJS.log(src, 'craft', { recipe = recipe.id, quality = quality, jars = jars, batch = batch, new = isNew })

    return {
        ok = true,
        recipe = {
            label = label, rarity = recipe.rarity, rarityLabel = rarity.label, rarityColor = rarity.color,
            image = recipe.image, color = recipe.color, description = recipe.description,
            ingredients = fruitLabels,
        },
        quality = quality,
        tier = { label = tier.label, color = tier.color },
        jars = jars,
        isNew = isNew,
        notes = notes,
        scores = session.scores,
        value = math.floor(recipe.value * tier.mult),
        batch = batch,
        rack = rack,
        achievements = unlocked,
    }
end

lib.callback.register('velora_jamco:craft:start', function(src, data)
    local cid = VJS.getCid(src)
    if not cid then return { ok = false, msg = 'Character not loaded.' } end
    if Sessions[src] then return { ok = false, msg = 'You are already cooking a batch.' } end
    local kitchen = nearKitchen(src)
    if not kitchen then return { ok = false, msg = 'You need to be at the jam kitchen.' } end
    local can, why = VJS.canAct(src)
    if not can then return { ok = false, msg = why } end
    if VJS.inVehicle(src) then return { ok = false, msg = 'Get out of the vehicle first.' } end
    if Config.RequireShift.kitchen and not VJS.onShift(src) then
        return { ok = false, msg = 'Start a shift at Velora Jam Co. first.' }
    end
    if Config.Crafting.RequireMixingBowl and VJS.count(src, Config.Supplies.bowl.item) < 1 then
        return { ok = false, msg = 'You need a mixing bowl. Rosalind sells them at the pantry.' }
    end

    local parsed, err = parseIngredients(data)
    if not parsed then return { ok = false, msg = err } end
    if not VJS.lock(src, 'craft') then return { ok = false, msg = 'Please wait...' } end

    local reqs = requirements(parsed)
    local ok, missing = VJS.takeItems(src, reqs)
    if not ok then
        VJS.unlock(src, 'craft')
        local label = missing
        for _, r in ipairs(reqs) do if r.item == missing then label = r.label end end
        return { ok = false, msg = ('You do not have enough %s.'):format(label) }
    end

    local pendingId = VJS.addPending(cid, 'refund', { items = reqs })
    if pendingId then VJS.LiveSessionRows[pendingId] = true end

    local recipe = VJS.RecipeByKey[VJS.recipeKey(parsed.fruits, parsed.special)] or ExperimentalRecipe
    local d = VJ.rarity(recipe.rarity).difficulty
    local mg = Config.Minigames
    local idealMin = mg.fill.idealMin + math.random(-3, 3)
    local idealMax = idealMin + math.max(4, (mg.fill.idealMax - mg.fill.idealMin) / d)
    local centre = (idealMin + idealMax) / 2
    local bandMin = mg.heat.bandMin + math.random(-2, 2)

    local params = {
        prepare = { targets = mg.prepare.targets + parsed.jars - 1, window = mg.prepare.window / d },
        heat = {
            startTemp = mg.heat.startTemp, bandMin = bandMin, bandMax = bandMin + mg.heat.bandWidth / d,
            cookSeconds = mg.heat.cookSeconds * math.sqrt(d), burnSeconds = mg.heat.burnSeconds,
        },
        stir = {
            revolutions = mg.stir.revolutions + parsed.jars - 1,
            burnRate = mg.stir.burnRate * d * (parsed.pectin and 0.8 or 1.0),
        },
        fill = {
            idealMin = idealMin, idealMax = idealMax,
            perfectMin = centre - mg.fill.perfectWidth / 2, perfectMax = centre + mg.fill.perfectWidth / 2,
            speed = mg.fill.speed, waste = mg.fill.waste,
        },
        seal = { attempts = mg.seal.attempts, zone = mg.seal.zone / d, perfect = mg.seal.perfect, speed = mg.seal.speed * d },
    }

    local session = {
        token = VJS.token(),
        cid = cid,
        kitchen = kitchen.id,
        recipe = recipe,
        parsed = parsed,
        reqs = reqs,
        pendingId = pendingId,
        stage = 1,
        stageStart = GetGameTimer(),
        scores = {},
        flags = {},
        params = params,
    }
    Sessions[src] = session
    VJS.unlock(src, 'craft')
    VJS.log(src, 'craft_start', { fruits = parsed.fruits, special = parsed.special, jars = parsed.jars })

    local fruitInfo = {}
    for _, id in ipairs(parsed.fruits) do
        local f = Config.Fruits[id]
        fruitInfo[#fruitInfo + 1] = { id = id, label = f.label, item = f.item, color = f.color }
    end

    return {
        ok = true,
        token = session.token,
        jars = parsed.jars,
        complexity = recipe.rarity == 'experimental' and 1 or VJ.rarity(recipe.rarity).order,
        fruits = fruitInfo,
        special = parsed.special and { id = parsed.special, label = Config.Specials[parsed.special].label, item = Config.Specials[parsed.special].item } or nil,
        pectin = parsed.pectin,
        params = params,
        stages = STAGES,
    }
end)

lib.callback.register('velora_jamco:craft:stage', function(src, token, stage, data)
    local session = Sessions[src]
    if not session or session.token ~= token then return { ok = false, msg = 'This batch is no longer active.', ended = true } end
    if STAGES[session.stage] ~= stage or type(data) ~= 'table' then return { ok = false, msg = 'Out of order.' } end
    if not VJS.lock(src, 'craft') then return { ok = false, msg = 'Please wait...' } end

    local elapsed = (GetGameTimer() - session.stageStart) / 1000
    if elapsed > Config.Crafting.StageTimeout or not nearKitchen(src) or VJS.isIncapacitated(src) then
        cancelSession(src, session, 'interrupted')
        VJS.unlock(src, 'craft')
        return { ok = false, ended = true, msg = 'You left the stove and the batch was ruined.' }
    end

    local score, info = 0, { implausible = true }
    if elapsed >= MIN_SECONDS[stage] then
        score, info = Evaluate[stage](session.params[stage], data, elapsed)
    end
    if info.implausible then
        VJS.log(src, 'craft_implausible', { stage = stage, elapsed = elapsed })
    end
    score = math.floor(score)
    session.scores[stage] = score
    if info.burned then session.flags.burned = true end
    if info.wasted then session.flags.wasted = true end
    if info.perfect and stage == 'fill' then session.flags.perfectFill = true end

    session.stage = session.stage + 1
    session.stageStart = GetGameTimer()

    local response = { ok = true, score = score, burned = info.burned or false, wasted = info.wasted or false }
    if session.stage > #STAGES then
        response.finished = finishSession(src, session)
    else
        response.next = STAGES[session.stage]
    end
    VJS.unlock(src, 'craft')
    return response
end)

lib.callback.register('velora_jamco:craft:cancel', function(src, token)
    local session = Sessions[src]
    if not session or session.token ~= token then return { ok = true } end
    if not VJS.lock(src, 'craft') then return { ok = false } end
    local early = cancelSession(src, session, 'cancelled')
    VJS.unlock(src, 'craft')
    return { ok = true, refundedAll = early and Config.Crafting.RefundOnCancelBeforeCooking }
end)

lib.callback.register('velora_jamco:kitchen:collect', function(src, id)
    local cid = VJS.getCid(src)
    if not cid or not nearKitchen(src) then return { ok = false, msg = 'You need to be at the jam kitchen.' } end
    if not VJS.lock(src, 'collect') then return { ok = false, msg = 'Please wait...' } end
    local result = { ok = false, msg = 'Nothing to collect.' }
    for _, row in ipairs(VJS.getPending(cid, 'jam')) do
        if row.id == tonumber(id) then
            if VJS.removePending(row.id) > 0 then
                local failed = VJS.giveItems(src, row.payload.items or {})
                if #failed > 0 then
                    VJS.addPending(cid, 'jam', { items = failed, note = row.payload.note })
                    result = { ok = false, msg = 'You cannot carry all of it. Make some space and try again.' }
                else
                    result = { ok = true, msg = 'Collected from the cooling rack.' }
                end
                VJS.log(src, 'rack_collect', { id = row.id, failed = #failed })
            end
            break
        end
    end
    result.rack = rackList(cid)
    VJS.unlock(src, 'collect')
    return result
end)

-- Disconnect mid-batch: convert the live session into a recoverable refund for next login
AddEventHandler('playerDropped', function()
    local src = source
    local session = Sessions[src]
    if not session then return end
    Sessions[src] = nil
    if session.pendingId then
        VJS.LiveSessionRows[session.pendingId] = nil
        local refund = refundFor(session, session.stage == 1)
        if #refund > 0 then
            MySQL.update('UPDATE velora_jamco_pending SET payload = ? WHERE id = ?', { json.encode({ items = refund }), session.pendingId })
        else
            MySQL.update('DELETE FROM velora_jamco_pending WHERE id = ?', { session.pendingId })
        end
    end
end)
