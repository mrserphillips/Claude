-- Velora Jam Co. - /selljam: customers walk up to the seller, negotiation and authoritative sales
--
-- Flow:  sell:toggle  -> selling mode on, first customer scheduled
--        sell:request -> (client polls) server issues ONE customer visit when it is due
--        sell:serve   -> player talks to the customer who arrived, gets their jar list
--        sell:offer / pitch / counter / accept -> negotiation + verified sale
--        sell:dismiss -> customer leaves (timeout, walked away, UI closed); next one is scheduled
local Selling = {}       -- src -> { nextAt }
local Visits = {}        -- src -> current customer visit / negotiation
local Market = {}        -- recipe id -> { sat, t }

local CFG = Config.Selling
local ox = exports.ox_inventory

local FirstNames = { 'Maggie', 'Tobias', 'Ellie', 'Marcus', 'June', 'Darnell', 'Priya', 'Owen', 'Rosa', 'Hank', 'Lucia', 'Theo', 'Imani', 'Gus', 'Wren', 'Delia', 'Frankie', 'Noor', 'Abe', 'Coral' }

local Lines = {
    greet = {
        casual = { 'Oh, homemade jam? Go on then, show me.', 'Ooh, that jar looks lovely. What have you got?', 'I could do with something sweet today.' },
        foodie = { 'Small-batch preserves? Now you have my attention.', 'Let me guess... hand-stirred? I can always tell.', 'I only buy jam that tells a story. Impress me.' },
        bargain = { 'Jam, huh? Depends what you\'re asking.', 'I\'m not paying boutique prices, just so you know.', 'Alright, what\'s the damage?' },
        collector = { 'Velora Jam Co.? I collect the rare ones. Got anything special?', 'Common jars bore me. Show me something unusual.', 'I hear some of your recipes are... legendary.' },
        cafe = { 'I run a little café in town - I could use some proper jam.', 'My customers have been asking for homemade jam.', 'If the quality\'s right, I\'m buying.' },
    },
    offer = { 'I could do %s for that.', 'How about %s?', 'I\'ll give you %s, final-ish offer.', '%s sounds fair to me.' },
    pitchGood = { 'Oh, you\'re good. Alright, I\'ll go a bit higher.', 'Well when you put it like that...', 'You\'ve convinced me. I\'ll sweeten the deal.' },
    pitchMeh = { 'Hm. Okay.', 'If you say so.', 'Right... anyway.' },
    pitchBad = { 'Rare? It\'s just jam, love.', 'That\'s not exactly what I\'d call premium.', 'Don\'t oversell it.' },
    accept = { 'Deal! Pleasure doing business.', 'Lovely - here you go.', 'Wonderful, I can\'t wait to try it.' },
    meet = { 'That\'s steep. Meet me in the middle - %s?', 'Hmm... I could stretch to %s.', 'Too rich for me. %s, and that\'s generous.' },
    insult = { 'Are you having a laugh?', 'For JAM? Absolutely not.', 'Now you\'re just being greedy.' },
    walk = { 'Forget it, I\'m off.', 'I\'ve wasted enough time. Bye.', 'No deal. Good luck with that.' },
}

local function pick(list) return list[math.random(1, #list)] end
local function money(n) return ('$%d'):format(math.floor(n)) end
local function between(range) return math.random(range[1], range[2]) end

local function weighted(list)
    local total = 0
    for _, t in ipairs(list) do total = total + t.weight end
    local roll = math.random() * total
    for _, t in ipairs(list) do
        roll = roll - t.weight
        if roll <= 0 then return t end
    end
    return list[1]
end

local function marketMult(recipeId)
    local m = Market[recipeId]
    if not m then return 1.0 end
    local now = os.time()
    m.sat = math.max(0, m.sat - CFG.Market.recoverPerMinute * (now - m.t) / 60)
    m.t = now
    return math.max(CFG.Market.floor, 1.0 - m.sat)
end

local function saturate(recipeId, qty)
    marketMult(recipeId)
    Market[recipeId] = Market[recipeId] or { sat = 0, t = os.time() }
    Market[recipeId].sat = Market[recipeId].sat + CFG.Market.perSale * qty
end

local function jamSlots(src)
    local list = {}
    local slots = ox:GetSlotsWithItem(src, Config.JamItem) or {}
    for _, slot in pairs(slots) do
        local meta = slot.metadata or {}
        if meta.recipe then
            local rarity = VJ.rarity(meta.rarity)
            list[#list + 1] = {
                slot = slot.slot, count = slot.count, label = meta.label or 'Jam', quality = meta.quality or 0,
                tier = meta.tier or VJ.qualityTier(meta.quality or 0).label, rarity = meta.rarity or 'common',
                rarityLabel = rarity.label, rarityColor = rarity.color,
                image = (VJS.Recipes[meta.recipe] or ExperimentalRecipe).image,
            }
        end
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return list
end

local function jamCount(src)
    return VJS.count(src, Config.JamItem)
end

local function blocked(src)
    if VJS.isIncapacitated(src) then return 'You cannot sell right now.' end
    if VJS.inVehicle(src) then return 'You cannot sell from a vehicle.' end
    return nil
end

local function schedule(src, range)
    local state = Selling[src]
    if state then state.nextAt = os.time() + between(range or CFG.CustomerInterval) end
end

local function endSelling(src)
    Selling[src] = nil
    Visits[src] = nil
    TriggerClientEvent('velora_jamco:client:sellingState', src, false)
end

-- ─────────────────────────────────────────────────────────────────────────
-- Price calculation (never trusts the client)
-- ─────────────────────────────────────────────────────────────────────────
local function priceFor(visit, meta, count)
    local recipe = VJS.Recipes[meta.recipe] or ExperimentalRecipe
    local quality = VJ.clamp(tonumber(meta.quality) or 0, 0, 100)
    local tier = VJ.qualityTier(quality)
    local rarity = VJ.rarity(recipe.rarity)
    local ctype = visit.ctype

    local per = recipe.value * tier.mult * (0.9 + quality * 0.002) * visit.typeMult * marketMult(recipe.id)
    if visit.preference and meta.fruits and (',' .. meta.fruits .. ','):find(',' .. visit.preference .. ',', 1, true) then
        per = per * (1 + CFG.FlavourBonus)
    end
    if ctype.rarityBonus and rarity.order >= 3 then per = per * (1 + ctype.rarityBonus) end
    if ctype.minRarity then
        if rarity.order < VJ.rarity(ctype.minRarity).order then per = per * 0.8 else per = per * 1.05 end
    end

    local qty = math.max(1, math.min(visit.want, count))
    local total = per * qty * (1 + CFG.BulkBonus * (qty - 1))
    return math.max(1, math.floor(total)), qty, recipe
end

-- ─────────────────────────────────────────────────────────────────────────
-- Selling mode & customer visits
-- ─────────────────────────────────────────────────────────────────────────
lib.callback.register('velora_jamco:sell:toggle', function(src)
    if Selling[src] then
        endSelling(src)
        return { active = false, msg = 'You stop selling jam.' }
    end
    local why = blocked(src)
    if why then return { active = false, msg = why } end
    local count = jamCount(src)
    if count < 1 then return { active = false, msg = 'You do not have any jars of jam to sell.' } end
    Selling[src] = { nextAt = 0 }
    schedule(src, CFG.FirstCustomerDelay)
    return { active = true, count = count, msg = ('Selling mode on - you have %d jar%s. Stay on foot and customers will come to you.'):format(count, count == 1 and '' or 's') }
end)

-- The client polls this; a customer is only issued when one is due
lib.callback.register('velora_jamco:sell:request', function(src)
    local state = Selling[src]
    if not state then return { ok = false, stop = true } end
    if Visits[src] then return { ok = false, retryIn = 5 } end
    local now = os.time()
    if now < state.nextAt then return { ok = false, retryIn = state.nextAt - now } end
    if blocked(src) then return { ok = false, retryIn = 3 } end
    if jamCount(src) < 1 then
        endSelling(src)
        return { ok = false, stop = true, msg = 'You have run out of jam.' }
    end

    local ctype = weighted(CFG.CustomerTypes)
    local preference = nil
    if math.random() < CFG.FlavourPreferenceChance then
        preference = Config.FruitOrder[math.random(1, #Config.FruitOrder)]
    end
    local visit = {
        token = VJS.token(),
        ctype = ctype,
        typeMult = ctype.mult[1] + math.random() * (ctype.mult[2] - ctype.mult[1]),
        preference = preference,
        want = weighted(CFG.Quantity).amount,
        patience = ctype.patience,
        mood = 55,
        pitched = false,
        served = false,
        issued = now,
        name = FirstNames[math.random(1, #FirstNames)],
        model = CFG.CustomerModels[math.random(1, #CFG.CustomerModels)],
    }
    Visits[src] = visit
    return { ok = true, token = visit.token, model = visit.model, name = visit.name }
end)

local function current(src, token)
    local visit = Visits[src]
    if not visit or (token and visit.token ~= token) then return nil, 'They have lost interest.' end
    local now = os.time()
    local limit = visit.served and CFG.NegotiationTimeout or (CFG.ArriveTimeout + CFG.WaitTimeout + 15)
    if now - (visit.served or visit.issued) > limit then
        Visits[src] = nil
        schedule(src)
        return nil, 'They got bored and wandered off.'
    end
    return visit
end

lib.callback.register('velora_jamco:sell:serve', function(src, token)
    local visit, err = current(src, token)
    if not visit then return { ok = false, msg = err } end
    local why = blocked(src)
    if why then return { ok = false, msg = why } end
    local jars = jamSlots(src)
    if #jars < 1 then
        Visits[src] = nil
        endSelling(src)
        return { ok = false, msg = 'You have run out of jam.' }
    end
    visit.served = os.time()

    local greet = pick(Lines.greet[visit.ctype.id] or Lines.greet.casual)
    if visit.preference then
        greet = greet .. (' I absolutely adore anything with %s in it.'):format(Config.Fruits[visit.preference].label:lower())
    end
    greet = greet .. (visit.want > 1 and (' I\'d like %d jars, if you have them.'):format(visit.want) or ' Just the one jar for me.')

    return {
        ok = true,
        customer = {
            name = visit.name, type = visit.ctype.id, typeLabel = visit.ctype.label, line = greet, mood = visit.mood,
            patience = visit.patience, maxPatience = visit.ctype.patience, want = visit.want,
            preference = visit.preference and Config.Fruits[visit.preference].label or nil,
        },
        jars = jars,
    }
end)

-- Customer leaves without buying (timed out, player walked off, UI closed)
lib.callback.register('velora_jamco:sell:dismiss', function(src, token)
    local visit = Visits[src]
    if visit and (not token or visit.token == token) then
        Visits[src] = nil
        schedule(src)
    end
    return true
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Negotiation
-- ─────────────────────────────────────────────────────────────────────────
local function active(src)
    local visit, err = current(src)
    if not visit then return nil, err end
    if not visit.served then return nil, 'Serve the customer first.' end
    return visit
end

local function walkOff(src)
    Visits[src] = nil
    schedule(src)
end

lib.callback.register('velora_jamco:sell:offer', function(src, slot)
    local visit, err = active(src)
    if not visit then return { ok = false, ended = true, msg = err } end
    local item = ox:GetSlot(src, tonumber(slot) or -1)
    if not item or item.name ~= Config.JamItem or not item.metadata or not item.metadata.recipe then
        return { ok = false, msg = 'That jar is no longer in your pockets.' }
    end
    local price, qty, recipe = priceFor(visit, item.metadata, item.count)
    visit.slot = item.slot
    visit.batch = item.metadata.batch
    visit.qty = qty
    visit.recipe = recipe.id
    visit.offer = price
    visit.max = math.floor(price * (1 + visit.ctype.haggle))
    visit.countered = false

    local line = pick(Lines.offer):format(money(price))
    if qty < visit.want then
        line = ('You only have %d of those? That\'s fine. '):format(qty) .. line
    elseif qty > 1 then
        line = ('%d jars of %s... '):format(qty, item.metadata.label) .. line
    end
    return { ok = true, offer = price, qty = qty, line = line, mood = visit.mood, patience = visit.patience }
end)

lib.callback.register('velora_jamco:sell:pitch', function(src, pitch)
    local visit, err = active(src)
    if not visit then return { ok = false, ended = true, msg = err } end
    if not visit.offer then return { ok = false, msg = 'Show them a jar first.' } end
    if visit.pitched then return { ok = false, msg = 'You have already made your pitch.' } end
    local valid = { compliment = true, flavour = true, rarity = true, deal = true, quality = true }
    if not valid[pitch] then return { ok = false, msg = 'Invalid pitch.' } end
    visit.pitched = true

    local item = ox:GetSlot(src, visit.slot)
    local meta = item and item.metadata or {}
    local rarityOrder = VJ.rarity(meta.rarity).order
    local tierMult = VJ.qualityTier(tonumber(meta.quality) or 0).mult

    local line, effect
    if pitch == visit.ctype.likes then
        visit.offer = math.floor(visit.offer * (1 + CFG.PitchBonus))
        visit.max = math.floor(visit.max * (1 + CFG.PitchBonus))
        visit.mood = math.min(100, visit.mood + 25)
        line, effect = pick(Lines.pitchGood), 'good'
    elseif (pitch == 'rarity' and rarityOrder < 3) or (pitch == 'quality' and tierMult < 1.0) then
        visit.patience = visit.patience - 1
        visit.mood = math.max(0, visit.mood - 15)
        line, effect = pick(Lines.pitchBad), 'bad'
    else
        visit.mood = math.min(100, visit.mood + 5)
        line, effect = pick(Lines.pitchMeh), 'neutral'
    end
    if visit.patience <= 0 then
        walkOff(src)
        return { ok = true, ended = true, effect = effect, line = pick(Lines.walk) }
    end
    return { ok = true, effect = effect, line = line, offer = visit.offer, mood = visit.mood, patience = visit.patience }
end)

local function performSale(src, visit, price, viaCounter)
    if not VJS.lock(src, 'sale') then return { ok = false, msg = 'Please wait...' } end
    local result = (function()
        local why = blocked(src)
        if why then return { ok = false, msg = why } end

        local item = ox:GetSlot(src, visit.slot)
        if not item or item.name ~= Config.JamItem or not item.metadata or item.metadata.batch ~= visit.batch or item.count < visit.qty then
            return { ok = false, ended = true, msg = 'That jar is no longer in your pockets.' }
        end

        -- clear the visit first: a repeated callback can never pay twice
        Visits[src] = nil
        schedule(src)
        if not ox:RemoveItem(src, Config.JamItem, visit.qty, nil, visit.slot) then
            return { ok = false, ended = true, msg = 'The sale could not be completed.' }
        end
        if not VJS.addMoney(src, Config.Payment.sales, price, 'velora-jamco-jam-sale', 'sale') then
            ox:AddItem(src, Config.JamItem, visit.qty, item.metadata)
            return { ok = false, ended = true, msg = 'Payment failed - your jam has been returned.' }
        end

        saturate(visit.recipe, visit.qty)
        local cid = VJS.getCid(src)
        local unlocked = {}
        if cid then
            local stats = VJS.getStats(cid)
            stats.jars_sold = stats.jars_sold + visit.qty
            stats.total_earned = stats.total_earned + price
            stats.best_sale = math.max(stats.best_sale, price)
            stats.customers = stats.customers + 1
            if viaCounter then stats.counters_won = stats.counters_won + 1 end
            VJS.saveStats(cid)
            unlocked = VJS.checkAchievements(src, cid)
        end
        VJS.log(src, 'sale', { recipe = visit.recipe, qty = visit.qty, price = price, batch = visit.batch, customer = visit.ctype.id, counter = viaCounter or false })

        local remaining = jamCount(src)
        if remaining < 1 then endSelling(src) end
        return {
            ok = true, sold = true, price = price, qty = visit.qty, label = item.metadata.label,
            line = pick(Lines.accept), remaining = remaining, sellingActive = Selling[src] ~= nil,
            achievements = unlocked,
        }
    end)()
    VJS.unlock(src, 'sale')
    return result
end

lib.callback.register('velora_jamco:sell:accept', function(src)
    local visit, err = active(src)
    if not visit then return { ok = false, ended = true, msg = err } end
    if not visit.offer then return { ok = false, msg = 'Show them a jar first.' } end
    return performSale(src, visit, visit.offer, visit.countered)
end)

lib.callback.register('velora_jamco:sell:counter', function(src, amount)
    local visit, err = active(src)
    if not visit then return { ok = false, ended = true, msg = err } end
    if not visit.offer then return { ok = false, msg = 'Show them a jar first.' } end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100000 then return { ok = false, msg = 'Enter a sensible price.' } end

    if amount <= visit.max then
        local result = performSale(src, visit, amount, amount > visit.offer)
        result.counterAccepted = true
        return result
    end

    visit.countered = true
    if amount <= math.floor(visit.max * 1.2) then
        visit.patience = visit.patience - 1
        visit.mood = math.max(0, visit.mood - 10)
        visit.offer = math.floor((visit.offer + visit.max) / 2)
        if visit.patience <= 0 then
            walkOff(src)
            return { ok = true, ended = true, line = pick(Lines.walk), mood = 0 }
        end
        return { ok = true, line = pick(Lines.meet):format(money(visit.offer)), offer = visit.offer, mood = visit.mood, patience = visit.patience, reaction = 'meet' }
    end

    visit.patience = visit.patience - 2
    visit.mood = math.max(0, visit.mood - 30)
    if visit.patience <= 0 then
        walkOff(src)
        return { ok = true, ended = true, line = pick(Lines.insult) .. ' ' .. pick(Lines.walk), mood = 0 }
    end
    return { ok = true, line = pick(Lines.insult), offer = visit.offer, mood = visit.mood, patience = visit.patience, reaction = 'insult' }
end)

AddEventHandler('playerDropped', function()
    Selling[source] = nil
    Visits[source] = nil
end)
