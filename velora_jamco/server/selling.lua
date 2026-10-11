-- Velora Jam Co. - /selljam: customers, negotiation and authoritative sales
local Selling = {}       -- src -> { lastApproach, rejects }
local Negotiations = {}  -- src -> negotiation state
local PedCooldowns = {}  -- ped net id -> os.time() when they can be approached again
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
        cafe = { 'I run a little café in town - I might need a few jars.', 'My customers have been asking for proper jam. How many have you got?', 'If the quality\'s right, I\'ll buy in bulk.' },
    },
    reject = { 'Sorry love, not today.', 'I\'m allergic to fun. And fruit.', 'No thanks, I\'m in a hurry.', 'Maybe next time, sweetheart.', 'I\'m trying to cut down on sugar.' },
    offer = { 'I could do %s for that.', 'How about %s?', 'I\'ll give you %s, final-ish offer.', '%s sounds fair to me.' },
    pitchGood = { 'Oh, you\'re good. Alright, I\'ll go a bit higher.', 'Well when you put it like that...', 'You\'ve convinced me. I\'ll sweeten the deal.' },
    pitchMeh = { 'Hm. Okay.', 'If you say so.', 'Right... anyway.' },
    pitchBad = { 'Rare? It\'s just jam, love.', 'That\'s not exactly what I\'d call premium.', 'Don\'t oversell it.' },
    accept = { 'Deal! Pleasure doing business.', 'Lovely - here you go.', 'Wonderful, I can\'t wait to try it.' },
    meet = { 'That\'s steep. Meet me in the middle - %s?', 'Hmm... I could stretch to %s.', 'Too rich for me. %s, and that\'s generous.' },
    insult = { 'Are you having a laugh?', 'For JAM? Absolutely not.', 'Now you\'re just being greedy.' },
    walk = { 'Forget it, I\'m off.', 'I\'ve wasted enough time. Bye.', 'No deal. Good luck with that.' },
    cooldown = { 'You already sold me some earlier!', 'I\'ve still got the last jar you sold me.' },
}

local function pick(list) return list[math.random(1, #list)] end
local function money(n) return ('$%d'):format(math.floor(n)) end

local function weightedType()
    local total = 0
    for _, t in ipairs(CFG.CustomerTypes) do total = total + t.weight end
    local roll = math.random() * total
    for _, t in ipairs(CFG.CustomerTypes) do
        roll = roll - t.weight
        if roll <= 0 then return t end
    end
    return CFG.CustomerTypes[1]
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

local function customerPed(src, netId)
    local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ped == 0 or not DoesEntityExist(ped) or GetEntityType(ped) ~= 1 or IsPedAPlayer(ped) then return nil, 'They are not interested.' end
    if GetEntityHealth(ped) <= 0 then return nil, 'They are in no state to buy jam.' end
    local playerPed = GetPlayerPed(src)
    if #(GetEntityCoords(playerPed) - GetEntityCoords(ped)) > CFG.MaxDistance then return nil, 'Get closer to them.' end
    if not CFG.AllowedPopTypes[GetEntityPopulationType(ped)] then return nil, 'They are not interested.' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil, 'They are driving.' end
    return ped
end

local function blocked(src)
    if VJS.isIncapacitated(src) then return 'You cannot sell right now.' end
    if VJS.inVehicle(src) then return 'You cannot sell from a vehicle.' end
    return nil
end

local function endSelling(src)
    Selling[src] = nil
    Negotiations[src] = nil
    TriggerClientEvent('velora_jamco:client:sellingState', src, false)
end

-- ─────────────────────────────────────────────────────────────────────────
-- Price calculation (never trusts the client)
-- ─────────────────────────────────────────────────────────────────────────
local function priceFor(neg, meta, count)
    local recipe = VJS.Recipes[meta.recipe] or ExperimentalRecipe
    local quality = VJ.clamp(tonumber(meta.quality) or 0, 0, 100)
    local tier = VJ.qualityTier(quality)
    local rarity = VJ.rarity(recipe.rarity)
    local ctype = neg.ctype

    local per = recipe.value * tier.mult * (0.9 + quality * 0.002) * neg.typeMult * marketMult(recipe.id)
    if neg.preference and meta.fruits and (',' .. meta.fruits .. ','):find(',' .. neg.preference .. ',', 1, true) then
        per = per * (1 + CFG.FlavourBonus)
    end
    if ctype.rarityBonus and rarity.order >= 3 then per = per * (1 + ctype.rarityBonus) end
    if ctype.minRarity then
        if rarity.order < VJ.rarity(ctype.minRarity).order then per = per * 0.8 else per = per * 1.05 end
    end

    local qty = 1
    if neg.bulk then qty = math.min(neg.bulk, count) end
    local total = per * qty * (1 + CFG.BulkBonus * (qty - 1))
    return math.max(1, math.floor(total)), qty, recipe
end

-- ─────────────────────────────────────────────────────────────────────────
-- Callbacks
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
    Selling[src] = { lastApproach = 0, rejects = 0 }
    return { active = true, count = count, msg = ('Selling mode on - you have %d jar%s. Approach locals to offer them jam.'):format(count, count == 1 and '' or 's') }
end)

lib.callback.register('velora_jamco:sell:approach', function(src, netId)
    local state = Selling[src]
    if not state then return { ok = false, msg = 'Use /' .. CFG.Command .. ' first.' } end
    local neg = Negotiations[src]
    if neg and os.time() - neg.started < CFG.NegotiationTimeout then return { ok = false, msg = 'Finish your current conversation first.' } end
    Negotiations[src] = nil

    local why = blocked(src)
    if why then return { ok = false, msg = why } end
    if os.time() - state.lastApproach < CFG.ApproachCooldown then return { ok = false, msg = 'Catch your breath for a moment.' } end
    if jamCount(src) < 1 then
        endSelling(src)
        return { ok = false, msg = 'You have run out of jam.' }
    end

    local ped, err = customerPed(src, netId)
    if not ped then return { ok = false, msg = err } end
    netId = tonumber(netId)
    if (PedCooldowns[netId] or 0) > os.time() then return { ok = false, msg = pick(Lines.cooldown), cooldown = true } end

    state.lastApproach = os.time()
    PedCooldowns[netId] = os.time() + CFG.PedCooldown

    if state.rejects < CFG.MaxConsecutiveRejects and math.random() < CFG.RejectChance then
        state.rejects = state.rejects + 1
        return { ok = false, rejected = true, msg = pick(Lines.reject) }
    end
    state.rejects = 0

    local ctype = weightedType()
    local preference = nil
    if math.random() < CFG.FlavourPreferenceChance then
        preference = Config.FruitOrder[math.random(1, #Config.FruitOrder)]
    end
    local bulk = ctype.bulk and math.random(ctype.bulk[1], ctype.bulk[2]) or nil

    neg = {
        netId = netId,
        ctype = ctype,
        typeMult = ctype.mult[1] + math.random() * (ctype.mult[2] - ctype.mult[1]),
        preference = preference,
        bulk = bulk,
        patience = ctype.patience,
        mood = 55,
        pitched = false,
        started = os.time(),
        name = FirstNames[math.random(1, #FirstNames)],
    }
    Negotiations[src] = neg

    local greet = pick(Lines.greet[ctype.id] or Lines.greet.casual)
    if preference then
        greet = greet .. (' I absolutely adore anything with %s in it.'):format(Config.Fruits[preference].label:lower())
    end
    if bulk then greet = greet .. (' I\'m after %d jars, if you have them.'):format(bulk) end

    return {
        ok = true,
        customer = {
            name = neg.name, type = ctype.id, typeLabel = ctype.label, line = greet, mood = neg.mood,
            patience = neg.patience, maxPatience = ctype.patience, bulk = bulk,
            preference = preference and Config.Fruits[preference].label or nil,
        },
        jars = jamSlots(src),
    }
end)

local function active(src)
    local neg = Negotiations[src]
    if not neg then return nil, 'They have lost interest.' end
    if os.time() - neg.started > CFG.NegotiationTimeout then
        Negotiations[src] = nil
        return nil, 'They got bored and wandered off.'
    end
    return neg
end

lib.callback.register('velora_jamco:sell:offer', function(src, slot)
    local neg, err = active(src)
    if not neg then return { ok = false, ended = true, msg = err } end
    local item = ox:GetSlot(src, tonumber(slot) or -1)
    if not item or item.name ~= Config.JamItem or not item.metadata or not item.metadata.recipe then
        return { ok = false, msg = 'That jar is no longer in your pockets.' }
    end
    local price, qty, recipe = priceFor(neg, item.metadata, item.count)
    neg.slot = item.slot
    neg.batch = item.metadata.batch
    neg.qty = qty
    neg.recipe = recipe.id
    neg.offer = price
    neg.max = math.floor(price * (1 + neg.ctype.haggle))
    neg.countered = false

    local line = pick(Lines.offer):format(money(price))
    if neg.bulk and qty < neg.bulk then
        line = ('You only have %d? Fine. '):format(qty) .. line
    elseif qty > 1 then
        line = ('%d jars of %s... '):format(qty, item.metadata.label) .. line
    end
    return { ok = true, offer = price, qty = qty, line = line, mood = neg.mood, patience = neg.patience }
end)

lib.callback.register('velora_jamco:sell:pitch', function(src, pitch)
    local neg, err = active(src)
    if not neg then return { ok = false, ended = true, msg = err } end
    if not neg.offer then return { ok = false, msg = 'Show them a jar first.' } end
    if neg.pitched then return { ok = false, msg = 'You have already made your pitch.' } end
    local valid = { compliment = true, flavour = true, rarity = true, deal = true, quality = true }
    if not valid[pitch] then return { ok = false, msg = 'Invalid pitch.' } end
    neg.pitched = true

    local item = ox:GetSlot(src, neg.slot)
    local meta = item and item.metadata or {}
    local rarityOrder = VJ.rarity(meta.rarity).order
    local tierMult = VJ.qualityTier(tonumber(meta.quality) or 0).mult

    local line, effect
    if pitch == neg.ctype.likes then
        neg.offer = math.floor(neg.offer * (1 + CFG.PitchBonus))
        neg.max = math.floor(neg.max * (1 + CFG.PitchBonus))
        neg.mood = math.min(100, neg.mood + 25)
        line, effect = pick(Lines.pitchGood), 'good'
    elseif (pitch == 'rarity' and rarityOrder < 3) or (pitch == 'quality' and tierMult < 1.0) then
        neg.patience = neg.patience - 1
        neg.mood = math.max(0, neg.mood - 15)
        line, effect = pick(Lines.pitchBad), 'bad'
    else
        neg.mood = math.min(100, neg.mood + 5)
        line, effect = pick(Lines.pitchMeh), 'neutral'
    end
    if neg.patience <= 0 then
        Negotiations[src] = nil
        return { ok = true, ended = true, effect = effect, line = pick(Lines.walk) }
    end
    return { ok = true, effect = effect, line = line, offer = neg.offer, mood = neg.mood, patience = neg.patience }
end)

local function performSale(src, neg, price, viaCounter)
    if not VJS.lock(src, 'sale') then return { ok = false, msg = 'Please wait...' } end
    local result = (function()
        local why = blocked(src)
        if why then return { ok = false, msg = why } end
        if not customerPed(src, neg.netId) then return { ok = false, ended = true, msg = 'Your customer has walked off.' } end

        local item = ox:GetSlot(src, neg.slot)
        if not item or item.name ~= Config.JamItem or not item.metadata or item.metadata.batch ~= neg.batch or item.count < neg.qty then
            return { ok = false, ended = true, msg = 'That jar is no longer in your pockets.' }
        end

        -- clear the negotiation first: a repeated callback can never pay twice
        Negotiations[src] = nil
        if not ox:RemoveItem(src, Config.JamItem, neg.qty, nil, neg.slot) then
            return { ok = false, ended = true, msg = 'The sale could not be completed.' }
        end
        if not VJS.addMoney(src, Config.Payment.sales, price, 'velora-jamco-jam-sale', 'sale') then
            ox:AddItem(src, Config.JamItem, neg.qty, item.metadata)
            return { ok = false, ended = true, msg = 'Payment failed - your jam has been returned.' }
        end

        saturate(neg.recipe, neg.qty)
        local cid = VJS.getCid(src)
        local unlocked = {}
        if cid then
            local stats = VJS.getStats(cid)
            stats.jars_sold = stats.jars_sold + neg.qty
            stats.total_earned = stats.total_earned + price
            stats.best_sale = math.max(stats.best_sale, price)
            stats.customers = stats.customers + 1
            if viaCounter then stats.counters_won = stats.counters_won + 1 end
            VJS.saveStats(cid)
            unlocked = VJS.checkAchievements(src, cid)
        end
        VJS.log(src, 'sale', { recipe = neg.recipe, qty = neg.qty, price = price, batch = neg.batch, customer = neg.ctype.id, counter = viaCounter or false })

        local remaining = jamCount(src)
        if remaining < 1 then endSelling(src) end
        return {
            ok = true, sold = true, price = price, qty = neg.qty, label = item.metadata.label,
            line = pick(Lines.accept), remaining = remaining, sellingActive = Selling[src] ~= nil,
            achievements = unlocked,
        }
    end)()
    VJS.unlock(src, 'sale')
    return result
end

lib.callback.register('velora_jamco:sell:accept', function(src)
    local neg, err = active(src)
    if not neg then return { ok = false, ended = true, msg = err } end
    if not neg.offer then return { ok = false, msg = 'Show them a jar first.' } end
    return performSale(src, neg, neg.offer, neg.countered)
end)

lib.callback.register('velora_jamco:sell:counter', function(src, amount)
    local neg, err = active(src)
    if not neg then return { ok = false, ended = true, msg = err } end
    if not neg.offer then return { ok = false, msg = 'Show them a jar first.' } end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100000 then return { ok = false, msg = 'Enter a sensible price.' } end

    if amount <= neg.max then
        local won = amount > neg.offer
        local result = performSale(src, neg, amount, won)
        result.counterAccepted = true
        return result
    end

    neg.countered = true
    if amount <= math.floor(neg.max * 1.2) then
        neg.patience = neg.patience - 1
        neg.mood = math.max(0, neg.mood - 10)
        neg.offer = math.floor((neg.offer + neg.max) / 2)
        if neg.patience <= 0 then
            Negotiations[src] = nil
            return { ok = true, ended = true, line = pick(Lines.walk), mood = 0 }
        end
        return { ok = true, line = pick(Lines.meet):format(money(neg.offer)), offer = neg.offer, mood = neg.mood, patience = neg.patience, reaction = 'meet' }
    end

    neg.patience = neg.patience - 2
    neg.mood = math.max(0, neg.mood - 30)
    if neg.patience <= 0 then
        Negotiations[src] = nil
        return { ok = true, ended = true, line = pick(Lines.insult) .. ' ' .. pick(Lines.walk), mood = 0 }
    end
    return { ok = true, line = pick(Lines.insult), offer = neg.offer, mood = neg.mood, patience = neg.patience, reaction = 'insult' }
end)

lib.callback.register('velora_jamco:sell:cancel', function(src)
    Negotiations[src] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    Selling[source] = nil
    Negotiations[source] = nil
end)

-- prune expired ped cooldowns so the table never grows unbounded
CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for netId, expires in pairs(PedCooldowns) do
            if expires <= now then PedCooldowns[netId] = nil end
        end
    end
end)
