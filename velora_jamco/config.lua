--[[
    ██╗   ██╗███████╗██╗      ██████╗ ██████╗  █████╗
    ██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗
    ██║   ██║█████╗  ██║     ██║   ██║██████╔╝███████║
    ╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██╔══██╗██╔══██║
     ╚████╔╝ ███████╗███████╗╚██████╔╝██║  ██║██║  ██║
      ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   JAM CO.

    velora_jamco - shared configuration
    Recipes live in server/recipes.lua (server-only, so hidden ingredients
    can never be read from client files).

    Every coordinate marked  -- PLACEHOLDER  must be replaced with your own.
    Use the admin helpers in-game:
        /jamcoords            copies your current vec4 to the clipboard
        /jamtree <fruit>      copies a ready-made tree entry for config.lua
]]

Config = {}

Config.Debug = false

-- ─────────────────────────────────────────────────────────────────────────
-- General
-- ─────────────────────────────────────────────────────────────────────────
Config.BusinessName = 'Velora Jam Co.'

-- Admin permission used by /jamcoords, /jamtree and /jamreset
Config.AdminGroup = 'group.admin'

-- Which account each kind of transaction uses ('cash' or 'bank')
Config.Payment = {
    sales   = 'cash',  -- money paid by NPC customers
    deposit = 'bank',  -- van hire deposit is taken from / refunded to this account
}

-- Optional hook called on the server whenever money moves through this resource.
-- Use it to write statements into Lation Banking (or any banking script).
-- kind = 'sale' | 'deposit' | 'refund', amount is always positive.
-- Lation Banking reads the qbx_core bank balance directly, so nothing is
-- required here unless you want custom statement entries.
Config.OnMoneyTransaction = function(source, kind, account, amount, reason)
    -- Example (check the export name in YOUR version of lation_banking first):
    -- if account == 'bank' and GetResourceState('lation_banking') == 'started' then
    --     exports.lation_banking:AddTransaction(source, kind == 'deposit' and 'withdraw' or 'deposit', amount, reason)
    -- end
end

-- When true, players must have an active shift (hired van not required, see Van.Required)
-- before they can harvest or cook. Nobody ever needs a formal job.
Config.RequireShift = {
    harvest = false,
    kitchen = false,
}

-- ─────────────────────────────────────────────────────────────────────────
-- Business NPC  (the owner of Velora Jam Co.)
-- ─────────────────────────────────────────────────────────────────────────
Config.Business = {
    npc = {
        name     = 'Rosalind Vale',
        model    = 'a_f_y_hipster_02',
        coords   = vec4(1702.52, 4918.43, 42.06, 52.0),        -- PLACEHOLDER (Grapeseed Main St)
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    blip = { enabled = true, sprite = 478, colour = 48, scale = 0.8, label = 'Velora Jam Co.' },
    interactDistance = 2.5,
    -- Where the hired van can be parked to end a shift
    returnPoint  = vec3(1693.98, 4930.10, 42.08),            -- PLACEHOLDER
    returnRadius = 30.0,
}

-- ─────────────────────────────────────────────────────────────────────────
-- Company vans
-- ─────────────────────────────────────────────────────────────────────────
Config.Van = {
    Required = false,          -- true = a shift can only start with a hired van
    Deposit  = 500,            -- 0 disables the deposit
    -- Deposit is refunded when body AND engine health are at or above these (max 1000)
    RefundHealth = { body = 850.0, engine = 850.0 },
    PlatePrefix = 'VJC',       -- plate = prefix + 5 random characters (max 8 chars total)

    Models = {
        { model = 'speedo',   label = 'Vapid Speedo',     description = 'The classic delivery van. Reliable and roomy.' },
        { model = 'rumpo',    label = 'Bravado Rumpo',    description = 'Smooth handling for country lanes.' },
        { model = 'burrito3', label = 'Declasse Burrito', description = 'Tough enough for the orchard tracks.' },
    },

    -- GTA colour indexes (https://wiki.rage.mp/index.php?title=Vehicle_Colors)
    Colours = {
        { label = 'Velora Noir',     primary = 12,  secondary = 135, swatch = '#141014', accent = '#f06aa6' },
        { label = 'Raspberry Pink',  primary = 135, secondary = 12,  swatch = '#f06aa6', accent = '#141014' },
        { label = 'Clotted Cream',   primary = 107, secondary = 135, swatch = '#efe3c8', accent = '#f06aa6' },
        { label = 'Blackberry',      primary = 145, secondary = 12,  swatch = '#4b1f5c', accent = '#141014' },
        { label = 'Midnight Black',  primary = 0,   secondary = 0,   swatch = '#0b0b0d', accent = '#0b0b0d' },
    },

    -- Spawn points are tried in order; occupied points are skipped (no overlapping vans)
    Spawns = {
        vec4(1690.44, 4935.23, 42.08, 55.0),                  -- PLACEHOLDER
        vec4(1686.98, 4939.80, 42.08, 55.0),                  -- PLACEHOLDER
        vec4(1683.42, 4944.31, 42.08, 55.0),                  -- PLACEHOLDER
    },
    SpawnClearRadius = 3.5,
}

-- Vehicle keys. Server-side giving is preferred where the key script supports it.
-- Supported out of the box: 'qbx_vehiclekeys', 'wasabi_carlock', 'qs-vehiclekeys',
-- 'MrNewbVehicleKeys', 'mk_vehiclekeys', 'none'.
Config.VehicleKeys = 'qbx_vehiclekeys'

-- Fuel level set on the hired van (ox_fuel reads the statebag, others use exports client-side)
Config.VanFuel = 100.0

-- ─────────────────────────────────────────────────────────────────────────
-- Fruit, special ingredients and supplies
-- item  = ox_inventory item name (see install/ox_inventory_items.lua)
-- ─────────────────────────────────────────────────────────────────────────
Config.Fruits = {
    orange     = { item = 'fruit_orange',     label = 'Orange',     plural = 'Oranges',      color = '#f39a2b' },
    apple      = { item = 'fruit_apple',      label = 'Apple',      plural = 'Apples',       color = '#d9363e' },
    lemon      = { item = 'fruit_lemon',      label = 'Lemon',      plural = 'Lemons',       color = '#f5d33b' },
    cherry     = { item = 'fruit_cherry',     label = 'Cherry',     plural = 'Cherries',     color = '#b3122e' },
    peach      = { item = 'fruit_peach',      label = 'Peach',      plural = 'Peaches',      color = '#f7a26b' },
    strawberry = { item = 'fruit_strawberry', label = 'Strawberry', plural = 'Strawberries', color = '#e8273f' },
    blueberry  = { item = 'fruit_blueberry',  label = 'Blueberry',  plural = 'Blueberries',  color = '#3f5bb5' },
    blackberry = { item = 'fruit_blackberry', label = 'Blackberry', plural = 'Blackberries', color = '#3a1838' },
    raspberry  = { item = 'fruit_raspberry',  label = 'Raspberry',  plural = 'Raspberries',  color = '#e0315f' },
    plum       = { item = 'fruit_plum',       label = 'Plum',       plural = 'Plums',        color = '#6b2a6e' },
}
-- Display order everywhere in the UI
Config.FruitOrder = { 'orange', 'apple', 'lemon', 'cherry', 'peach', 'strawberry', 'blueberry', 'blackberry', 'raspberry', 'plum' }

-- One optional "special" slot per batch. golden is only obtained from harvesting.
Config.Specials = {
    cinnamon    = { item = 'jam_cinnamon',    label = 'Cinnamon',    color = '#8a4b22' },
    honey       = { item = 'jam_honey',       label = 'Wildflower Honey', color = '#e8a317' },
    vanilla     = { item = 'jam_vanilla',     label = 'Vanilla Pod', color = '#d9c39a' },
    lavender    = { item = 'jam_lavender',    label = 'Lavender',    color = '#9b7fd1' },
    rose_petals = { item = 'jam_rose_petals', label = 'Rose Petals', color = '#e05a8a' },
    golden      = { item = 'golden_fruit',    label = 'Golden Fruit', color = '#ffcf4a' },
}
Config.SpecialOrder = { 'cinnamon', 'honey', 'vanilla', 'lavender', 'rose_petals', 'golden' }

Config.Supplies = {
    sugar  = { item = 'jam_sugar',     label = 'Sugar' },
    jar    = { item = 'jam_jar_empty', label = 'Empty Jar' },
    lid    = { item = 'jam_jar_lid',   label = 'Jar Lid' },
    pectin = { item = 'jam_pectin',    label = 'Pectin' },
    bowl   = { item = 'jam_mixing_bowl', label = 'Mixing Bowl' },
    basket = { item = 'fruit_basket',  label = 'Fruit Basket' },
}

-- The finished product: one generic item, everything else lives in metadata
Config.JamItem = 'velora_jam'

-- Per-recipe jar icons are served straight from this resource through metadata.imageurl,
-- so they show in ox_inventory without copying 40+ images.
Config.JamImageUrl = 'nui://velora_jamco/web/images/jams/%s.png'

-- ─────────────────────────────────────────────────────────────────────────
-- Supplier shop (ox_inventory shop, opened from the business NPC)
-- ─────────────────────────────────────────────────────────────────────────
Config.Shop = {
    enabled = true,
    name    = 'Velora Pantry Supplies',
    currency = 'money',
    items = {
        { name = 'jam_sugar',       price = 6 },
        { name = 'jam_jar_empty',   price = 8 },
        { name = 'jam_jar_lid',     price = 3 },
        { name = 'jam_pectin',      price = 12 },
        { name = 'jam_cinnamon',    price = 18 },
        { name = 'jam_honey',       price = 22 },
        { name = 'jam_vanilla',     price = 28 },
        { name = 'jam_lavender',    price = 20 },
        { name = 'jam_rose_petals', price = 24 },
        { name = 'jam_mixing_bowl', price = 75 },
        { name = 'fruit_basket',    price = 45 },
    },
}

-- ─────────────────────────────────────────────────────────────────────────
-- Harvesting
-- ─────────────────────────────────────────────────────────────────────────
Config.Harvest = {
    InteractDistance = 2.2,   -- ox_target distance
    MaxDistance      = 4.0,   -- server-side + interruption distance
    GoldenChance     = 0.04,  -- chance a harvest round contains one golden fruit
    BasketBonus      = 2,     -- extra ripe fruit per round when carrying a fruit basket
    BasketGoldenBonus = 0.02, -- added golden chance with a basket
    PerfectBonus     = 1,     -- extra fruit for a flawless round (all ripe picked, no rotten)
    RottenPenalty    = 1,     -- fruit lost per rotten fruit clicked
    FallbackProp     = 'prop_bush_med_03',

    -- Animations by tree "anim" type
    Anims = {
        tree = { dict = 'amb@prop_human_movie_bulb@base', clip = 'base' },
        bush = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    },

    -- Minigame difficulty presets
    Difficulties = {
        easy   = { label = 'Easy',   time = 24, ripeWindow = 3.6, sway = 0.15, rottenRatio = 0.20, unripeTime = 1.2 },
        normal = { label = 'Normal', time = 22, ripeWindow = 2.9, sway = 0.45, rottenRatio = 0.35, unripeTime = 1.0 },
        hard   = { label = 'Hard',   time = 20, ripeWindow = 2.3, sway = 0.80, rottenRatio = 0.55, unripeTime = 0.8 },
    },
}

-- Orchards. Trees with a `prop` spawn that prop locally (works anywhere).
-- Set `prop = false` to target a real GTA tree/bush already standing at `coords`.
-- stock   = fruit available before the tree needs to restock
-- restock = seconds until a picked-clean tree is full again
-- yield   = ripe fruit offered per harvesting round
local function tree(id, fruit, x, y, z, opts)
    opts = opts or {}
    return {
        id = id,
        fruit = fruit,
        coords = vec3(x, y, z),
        prop = opts.prop == nil and 'prop_veg_crop_orange' or opts.prop,
        heading = opts.heading or 0.0,
        anim = opts.anim or 'tree',
        stock = opts.stock or 12,
        restock = opts.restock or 900,
        yield = opts.yield or { min = 3, max = 5 },
        difficulty = opts.difficulty or 'normal',
    }
end

local bush = function(id, fruit, x, y, z, opts)
    opts = opts or {}
    opts.prop = opts.prop == nil and 'prop_bush_med_03' or opts.prop
    opts.anim = opts.anim or 'bush'
    return tree(id, fruit, x, y, z, opts)
end

Config.Orchards = {
    {
        id = 'grapeseed',
        label = 'Grapeseed Orchard',
        description = 'Sun-warmed groves off Seaview Road. Oranges, stone fruit and berry hedges.',
        center = vec3(2355.0, 4765.0, 35.0),                  -- PLACEHOLDER
        blip = { enabled = true, sprite = 285, colour = 48, scale = 0.75 },
        trees = {
            -- PLACEHOLDER coordinates - replace with your own (props snap to the ground automatically)
            tree('gs_orange_1',  'orange', 2340.0, 4752.0, 35.0, { difficulty = 'easy' }),
            tree('gs_orange_2',  'orange', 2346.0, 4752.0, 35.0, { difficulty = 'easy' }),
            tree('gs_orange_3',  'orange', 2352.0, 4752.0, 35.0, { difficulty = 'easy' }),
            tree('gs_orange_4',  'orange', 2340.0, 4760.0, 35.0, { difficulty = 'easy' }),
            tree('gs_orange_5',  'orange', 2346.0, 4760.0, 35.0, { difficulty = 'easy' }),
            tree('gs_apple_1',   'apple',  2358.0, 4752.0, 35.0),
            tree('gs_apple_2',   'apple',  2364.0, 4752.0, 35.0),
            tree('gs_lemon_1',   'lemon',  2352.0, 4760.0, 35.0),
            tree('gs_lemon_2',   'lemon',  2358.0, 4760.0, 35.0),
            tree('gs_cherry_1',  'cherry', 2364.0, 4760.0, 35.0, { difficulty = 'hard', yield = { min = 4, max = 6 } }),
            tree('gs_cherry_2',  'cherry', 2370.0, 4760.0, 35.0, { difficulty = 'hard', yield = { min = 4, max = 6 } }),
            tree('gs_peach_1',   'peach',  2340.0, 4768.0, 35.0),
            tree('gs_peach_2',   'peach',  2346.0, 4768.0, 35.0),
            tree('gs_plum_1',    'plum',   2352.0, 4768.0, 35.0),
            tree('gs_plum_2',    'plum',   2358.0, 4768.0, 35.0),
            bush('gs_straw_1',   'strawberry', 2340.0, 4778.0, 35.0, { difficulty = 'easy', yield = { min = 4, max = 6 } }),
            bush('gs_straw_2',   'strawberry', 2344.0, 4778.0, 35.0, { difficulty = 'easy', yield = { min = 4, max = 6 } }),
            bush('gs_blue_1',    'blueberry',  2348.0, 4778.0, 35.0, { yield = { min = 4, max = 6 } }),
            bush('gs_blue_2',    'blueberry',  2352.0, 4778.0, 35.0, { yield = { min = 4, max = 6 } }),
            bush('gs_black_1',   'blackberry', 2356.0, 4778.0, 35.0, { difficulty = 'hard', yield = { min = 4, max = 6 } }),
            bush('gs_black_2',   'blackberry', 2360.0, 4778.0, 35.0, { difficulty = 'hard', yield = { min = 4, max = 6 } }),
            bush('gs_rasp_1',    'raspberry',  2364.0, 4778.0, 35.0, { yield = { min = 4, max = 6 } }),
            bush('gs_rasp_2',    'raspberry',  2368.0, 4778.0, 35.0, { yield = { min = 4, max = 6 } }),
        },
    },
}

-- ─────────────────────────────────────────────────────────────────────────
-- Jam kitchen(s)
-- If your interior has a real stove, set prop = false and put coords on the hob.
-- Otherwise a stove prop is spawned locally at prop.coords.
-- ─────────────────────────────────────────────────────────────────────────
Config.Kitchens = {
    {
        id = 'grapeseed_kitchen',
        label = 'Velora Jam Kitchen',
        coords = vec3(1699.20, 4914.62, 42.08),               -- PLACEHOLDER (interaction point / hob)
        radius = 0.9,
        maxDistance = 3.5,
        prop = { model = 'prop_cooker_03', coords = vec4(1699.20, 4914.62, 41.08, 145.0) }, -- PLACEHOLDER
        blip = { enabled = true, sprite = 436, colour = 48, scale = 0.7, label = 'Velora Jam Kitchen' },
        anim = { dict = 'amb@prop_human_bbq@male@base', clip = 'base' },
    },
}

-- ─────────────────────────────────────────────────────────────────────────
-- Crafting
-- ─────────────────────────────────────────────────────────────────────────
Config.Crafting = {
    MaxJarsPerBatch = 4,
    -- fruit pieces needed PER JAR for EACH fruit in the mix, by number of different fruits
    FruitPerJar = { [1] = 4, [2] = 2, [3] = 2 },
    SugarPerJar = 1,
    -- special ingredient (cinnamon, honey, golden fruit...) is used once per batch
    SpecialPerBatch = 1,
    PectinQualityBonus = 4,      -- optional: one pectin per batch, also makes stirring easier
    RequireMixingBowl = true,    -- mixing bowl is a tool (never consumed)
    -- if a batch is cancelled during preparation everything is refunded,
    -- after that only the (unused) jars and lids come back
    RefundOnCancelBeforeCooking = true,
    StageTimeout = 150,          -- seconds a single stage may take before the batch fails
}

-- Quality weight of each minigame (must add up to 1.0)
Config.QualityWeights = { prepare = 0.15, heat = 0.30, stir = 0.25, fill = 0.15, seal = 0.15 }

Config.QualityTiers = {   -- checked top to bottom
    { min = 95, label = 'Perfect Batch', mult = 1.25, color = '#ffd36b' },
    { min = 80, label = 'Premium',       mult = 1.10, color = '#f06aa6' },
    { min = 60, label = 'Fine',          mult = 1.00, color = '#c9a0dc' },
    { min = 40, label = 'Homemade',      mult = 0.85, color = '#d9b98c' },
    { min = 0,  label = 'Poor',          mult = 0.60, color = '#8d7f7f' },
}

-- Minigame tuning (difficulty is multiplied by the recipe rarity difficulty)
Config.Minigames = {
    prepare = { targets = 8, window = 1.25 },                       -- seconds per target
    heat    = { startTemp = 55, bandMin = 101, bandWidth = 8, cookSeconds = 14, burnSeconds = 4.5 },
    stir    = { revolutions = 12, burnRate = 0.085 },              -- burn meter gain per second
    fill    = { idealMin = 86, idealMax = 96, perfectWidth = 3, speed = 24, waste = 101 },
    seal    = { attempts = 3, zone = 34, perfect = 9, speed = 210 }, -- degrees / degrees / deg per second
}

-- ─────────────────────────────────────────────────────────────────────────
-- Rarity tiers. value = default base sale value of a recipe in that tier.
-- ─────────────────────────────────────────────────────────────────────────
Config.Rarities = {
    experimental = { label = 'Experimental', order = 0, value = 55,  difficulty = 1.00, color = '#9c8f8f' },
    common       = { label = 'Common',       order = 1, value = 95,  difficulty = 1.00, color = '#c9b8a8' },
    uncommon     = { label = 'Uncommon',     order = 2, value = 135, difficulty = 1.10, color = '#f06aa6' },
    rare         = { label = 'Rare',         order = 3, value = 185, difficulty = 1.22, color = '#f5b942' },
    epic         = { label = 'Epic',         order = 4, value = 255, difficulty = 1.35, color = '#b46cff' },
    legendary    = { label = 'Legendary',    order = 5, value = 380, difficulty = 1.50, color = '#ffd36b' },
}

-- ─────────────────────────────────────────────────────────────────────────
-- Discovery
-- ─────────────────────────────────────────────────────────────────────────
Config.Discovery = {
    -- When true, the mixing preview hints that an unknown combination is a real recipe
    -- (without revealing its name). When false, every unknown mix looks the same.
    HintValidCombos = true,
}

-- ─────────────────────────────────────────────────────────────────────────
-- Selling (/selljam)
-- ─────────────────────────────────────────────────────────────────────────
Config.Selling = {
    Command = 'selljam',
    InteractDistance = 2.0,
    MaxDistance = 4.0,            -- server-side check between player and customer
    PedCooldown = 900,            -- seconds before the same NPC can be approached again
    ApproachCooldown = 6,         -- seconds between approaches for one player
    RejectChance = 0.15,          -- chance a customer is simply not interested
    MaxConsecutiveRejects = 2,    -- after this many rejections in a row the next one always listens
    NegotiationTimeout = 120,     -- seconds before an open conversation expires
    BulkBonus = 0.06,             -- per extra jar in a bulk order
    -- Only ambient population peds can be customers (never scripted / mission peds)
    AllowedPopTypes = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },

    -- Market saturation: every jar of a recipe sold lowers its price a little, recovering over time
    Market = { perSale = 0.025, floor = 0.65, recoverPerMinute = 0.01 },

    -- Customer archetypes. likes = the sales pitch they respond to best.
    CustomerTypes = {
        { id = 'casual',    label = 'Casual Shopper', weight = 38, mult = { 0.88, 1.00 }, haggle = 0.12, patience = 2, likes = 'compliment' },
        { id = 'foodie',    label = 'Foodie',         weight = 22, mult = { 0.98, 1.12 }, haggle = 0.16, patience = 3, likes = 'flavour', rarityBonus = 0.10 },
        { id = 'bargain',   label = 'Bargain Hunter', weight = 18, mult = { 0.72, 0.86 }, haggle = 0.28, patience = 4, likes = 'deal' },
        { id = 'collector', label = 'Collector',      weight = 10, mult = { 1.02, 1.20 }, haggle = 0.10, patience = 2, likes = 'rarity', minRarity = 'rare' },
        { id = 'cafe',      label = 'Café Owner',     weight = 12, mult = { 0.92, 1.04 }, haggle = 0.10, patience = 3, likes = 'quality', bulk = { 2, 4 } },
    },
    FlavourPreferenceChance = 0.45,  -- chance a customer has a favourite fruit
    FlavourBonus = 0.18,             -- extra paid when the jam contains their favourite fruit
    PitchBonus = 0.07,               -- offer increase when the pitch matches what they like
}

-- ─────────────────────────────────────────────────────────────────────────
-- Achievements
-- ─────────────────────────────────────────────────────────────────────────
Config.Achievements = {
    { id = 'first_batch',        label = 'First Batch',         description = 'Seal your very first jar of jam.' },
    { id = 'orchard_explorer',   label = 'Orchard Explorer',    description = 'Harvest every type of fruit at least once.' },
    { id = 'golden_touch',       label = 'Golden Touch',        description = 'Find a golden fruit.' },
    { id = 'mad_scientist',      label = 'Mad Scientist',       description = 'Create 10 experimental jams.' },
    { id = 'perfectionist',      label = 'Perfectionist',       description = 'Produce a Perfect Batch (95%+ quality).' },
    { id = 'smooth_talker',      label = 'Smooth Talker',       description = 'Win 10 counteroffers.' },
    { id = 'master_jam_maker',   label = 'Master Jam Maker',    description = 'Discover 25 recipes.' },
    { id = 'legendary_preserver',label = 'Legendary Preserver', description = 'Craft a Legendary jam.' },
    { id = 'jam_tycoon',         label = 'Jam Tycoon',          description = 'Earn $25,000 from jam sales.' },
    { id = 'veloras_finest',     label = "Velora's Finest",     description = 'Discover every recipe in the book.' },
}

-- ─────────────────────────────────────────────────────────────────────────
-- Logging
-- ─────────────────────────────────────────────────────────────────────────
Config.Logging = {
    console  = true,
    database = true,      -- velora_jamco_logs table
    -- Discord webhook lives in server/sv_config.lua so it is never sent to clients
}
