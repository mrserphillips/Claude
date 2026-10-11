--[[
    Velora Jam Co. recipe book  (SERVER ONLY - never sent to clients until discovered)

    fruits  : 1-3 fruit ids from Config.Fruits (order does not matter)
    special : optional special ingredient id from Config.Specials
    rarity  : experimental | common | uncommon | rare | epic | legendary
    value   : optional base sale value override (otherwise Config.Rarities[rarity].value)
    image   : icon in web/images/jams/<image>.png  (numbered so file names reveal nothing)
    color   : jam colour used by the UI / icons, color2 = optional swirl colour

    The same ingredients always produce the same recipe (deterministic).
    Ids must be unique and must never be renamed once players have discovered them.
]]

Recipes = {
    -- ── Single fruit (Common) ─────────────────────────────────────────────
    { id = 'strawberry_jam', label = 'Strawberry Jam',   fruits = { 'strawberry' }, rarity = 'common', image = 'jar_01', color = '#c8102e', description = 'The timeless classic. Sweet, bright and glossy.' },
    { id = 'orange_marmalade', label = 'Orange Marmalade', fruits = { 'orange' },   rarity = 'common', image = 'jar_02', color = '#e8781a', description = 'Bittersweet peel suspended in sunshine.' },
    { id = 'apple_jam',      label = 'Orchard Apple',    fruits = { 'apple' },      rarity = 'common', image = 'jar_03', color = '#c9862e', description = 'Soft, mellow and a little nostalgic.' },
    { id = 'lemon_jam',      label = 'Lemon Preserve',   fruits = { 'lemon' },      rarity = 'common', image = 'jar_04', color = '#f2c81f', description = 'Sharp, zesty and wonderfully bright.' },
    { id = 'cherry_jam',     label = 'Cherry Jam',       fruits = { 'cherry' },     rarity = 'common', image = 'jar_05', color = '#8e0c24', value = 105, description = 'Deep red cherries cooked low and slow.' },
    { id = 'peach_jam',      label = 'Peach Jam',        fruits = { 'peach' },      rarity = 'common', image = 'jar_06', color = '#f08a43', description = 'Summer in a jar.' },
    { id = 'blueberry_jam',  label = 'Blueberry Jam',    fruits = { 'blueberry' },  rarity = 'common', image = 'jar_07', color = '#2e2f7a', value = 100, description = 'Wild blueberries with a whisper of tartness.' },
    { id = 'blackberry_jam', label = 'Bramble Jelly',    fruits = { 'blackberry' }, rarity = 'common', image = 'jar_08', color = '#2a0f2b', value = 100, description = 'Hedgerow blackberries, inky and rich.' },
    { id = 'raspberry_jam',  label = 'Raspberry Jam',    fruits = { 'raspberry' },  rarity = 'common', image = 'jar_09', color = '#c4173f', value = 100, description = 'Tangy, seedy and utterly irresistible.' },
    { id = 'plum_jam',       label = 'Damson Plum',      fruits = { 'plum' },       rarity = 'common', image = 'jar_10', color = '#5a1a52', description = 'Dusky plums with a velvet finish.' },

    -- ── Two fruits (Uncommon) ─────────────────────────────────────────────
    { id = 'blushing_hearts',  label = 'Blushing Hearts',  fruits = { 'strawberry', 'raspberry' }, rarity = 'uncommon', image = 'jar_11', color = '#d01849', color2 = '#ff7aa2', description = 'Two red berries falling madly in love.' },
    { id = 'golden_hour',      label = 'Golden Hour',      fruits = { 'orange', 'peach' },         rarity = 'uncommon', image = 'jar_12', color = '#f39a2b', color2 = '#ffd17a', description = 'The last warm light of a summer evening.' },
    { id = 'midnight_orchard', label = 'Midnight Orchard', fruits = { 'blackberry', 'blueberry' }, rarity = 'uncommon', image = 'jar_13', color = '#231a4d', color2 = '#4b3c9e', description = 'Dark berries picked by moonlight.' },
    { id = 'velvet_kiss',      label = 'Velvet Kiss',      fruits = { 'cherry', 'plum' },          rarity = 'uncommon', image = 'jar_14', color = '#6e0f3a', color2 = '#a3164f', value = 150, description = 'Lush, dark and dangerously smooth.' },
    { id = 'pink_lemonade',    label = 'Pink Lemonade',    fruits = { 'strawberry', 'lemon' },     rarity = 'uncommon', image = 'jar_15', color = '#f0547a', color2 = '#ffe36b', description = 'Fizzy fairground nostalgia.' },
    { id = 'summer_romance',   label = 'Summer Romance',   fruits = { 'raspberry', 'peach' },      rarity = 'uncommon', image = 'jar_16', color = '#ee5a5a', color2 = '#ffb27a', description = 'A holiday fling you will never forget.' },
    { id = 'thorn_and_honey',  label = 'Thorn & Honey',    fruits = { 'blackberry', 'lemon' },     rarity = 'uncommon', image = 'jar_17', color = '#3d1440', color2 = '#e8b33a', description = 'Sharp edges, sweet heart.' },
    { id = 'crimson_sunset',   label = 'Crimson Sunset',   fruits = { 'cherry', 'orange' },        rarity = 'uncommon', image = 'jar_18', color = '#b4231c', color2 = '#f39a2b', description = 'Fire across the evening sky.' },
    { id = 'bramble_cottage',  label = 'Bramble Cottage',  fruits = { 'apple', 'blackberry' },     rarity = 'uncommon', image = 'jar_19', color = '#4a1636', color2 = '#c9862e', description = 'Crumble-ready comfort from the hedgerow.' },
    { id = 'moonlit_meadow',   label = 'Moonlit Meadow',   fruits = { 'blueberry', 'lemon' },      rarity = 'uncommon', image = 'jar_20', color = '#34408f', color2 = '#f2d84a', description = 'Cool, bright and quietly magical.' },
    { id = 'harvest_lantern',  label = 'Harvest Lantern',  fruits = { 'apple', 'plum' },           rarity = 'uncommon', image = 'jar_21', color = '#7a2b4a', color2 = '#d0903a', description = 'Glows like a lantern on a cold night.' },
    { id = 'garden_party',     label = 'Garden Party',     fruits = { 'strawberry', 'peach' },     rarity = 'uncommon', image = 'jar_22', color = '#f25d5d', color2 = '#ffc08a', description = 'Lace tablecloths and afternoon tea.' },
    { id = 'sour_sweetheart',  label = 'Sour Sweetheart',  fruits = { 'raspberry', 'lemon' },      rarity = 'uncommon', image = 'jar_23', color = '#e2264f', color2 = '#ffe46b', description = 'Puckering, pink and playful.' },
    { id = 'orchard_blush',    label = 'Orchard Blush',    fruits = { 'apple', 'cherry' },         rarity = 'uncommon', image = 'jar_24', color = '#a8182f', color2 = '#e0a050', description = 'Rosy-cheeked and wholesome.' },

    -- ── Special ingredient pairings (Rare) ────────────────────────────────
    { id = 'autumn_embrace',   label = 'Autumn Embrace',   fruits = { 'apple' },      special = 'cinnamon',    rarity = 'rare', image = 'jar_25', color = '#9a4f1c', color2 = '#e2a35a', description = 'Warm spice wrapped around soft apple.' },
    { id = 'honeyed_dusk',     label = 'Honeyed Dusk',     fruits = { 'peach' },      special = 'honey',       rarity = 'rare', image = 'jar_26', color = '#e88a2a', color2 = '#ffd36b', description = 'Golden peaches dripping with wildflower honey.' },
    { id = 'silk_ribbon',      label = 'Silk Ribbon',      fruits = { 'strawberry' }, special = 'vanilla',     rarity = 'rare', image = 'jar_27', color = '#e24a6a', color2 = '#f5e6c8', description = 'Strawberries and vanilla, tied with a bow.' },
    { id = 'lavender_lullaby', label = 'Lavender Lullaby', fruits = { 'blueberry' },  special = 'lavender',    rarity = 'rare', image = 'jar_28', color = '#4b3f99', color2 = '#b9a2ea', description = 'Sleepy, floral and softly sweet.' },
    { id = 'rosebound',        label = 'Rosebound',        fruits = { 'raspberry' },  special = 'rose_petals', rarity = 'rare', image = 'jar_29', color = '#c21d4f', color2 = '#ff8fb4', description = 'A love letter written in petals.' },
    { id = 'mulled_midnight',  label = 'Mulled Midnight',  fruits = { 'plum' },       special = 'cinnamon',    rarity = 'rare', image = 'jar_30', color = '#4a1338', color2 = '#a8592a', description = 'Spiced plums by a crackling fire.' },
    { id = 'bees_knees',       label = "Bee's Knees",      fruits = { 'lemon' },      special = 'honey',       rarity = 'rare', image = 'jar_31', color = '#f0b81f', color2 = '#fff1a8', description = 'Bright lemon curd kissed by the hive.' },

    -- ── Three fruits (Rare) ───────────────────────────────────────────────
    { id = 'witching_hour',    label = 'Witching Hour',    fruits = { 'blueberry', 'raspberry', 'blackberry' }, rarity = 'rare', image = 'jar_32', color = '#2c0f33', color2 = '#c4173f', description = 'Three berries, one spell, no turning back.' },
    { id = 'cupids_curse',     label = "Cupid's Curse",    fruits = { 'strawberry', 'cherry', 'raspberry' },   rarity = 'rare', image = 'jar_33', color = '#b0102f', color2 = '#ff6f9c', description = 'Once tasted, forever smitten.' },
    { id = 'liquid_sunshine',  label = 'Liquid Sunshine',  fruits = { 'orange', 'lemon', 'peach' },            rarity = 'rare', image = 'jar_34', color = '#f5a623', color2 = '#ffe46b', description = 'Bottled daylight for grey mornings.' },
    { id = 'hedgerow_waltz',   label = 'Hedgerow Waltz',   fruits = { 'apple', 'blackberry', 'raspberry' },   rarity = 'rare', image = 'jar_35', color = '#5a1235', color2 = '#d63a63', description = 'A country dance through the brambles.' },

    -- ── Epic ──────────────────────────────────────────────────────────────
    { id = 'dark_fairytale',   label = 'Dark Fairytale',   fruits = { 'plum', 'blackberry', 'cherry' },        rarity = 'epic', image = 'jar_36', color = '#2a0820', color2 = '#8e0c3a', description = 'Not every story ends sweetly... this one does.' },
    { id = 'hollows_eve',      label = "Hollow's Eve",     fruits = { 'apple', 'plum', 'blackberry' }, special = 'cinnamon', rarity = 'epic', image = 'jar_37', color = '#3a0f24', color2 = '#c0662a', description = 'Spiced, shadowy and made for October nights.' },
    { id = 'bleeding_heart',   label = 'Bleeding Heart',   fruits = { 'cherry', 'raspberry' }, special = 'rose_petals', rarity = 'epic', image = 'jar_38', color = '#8a0022', color2 = '#ff4f86', description = 'Romantic, dramatic and a little tragic.' },
    { id = 'phoenix_feather',  label = 'Phoenix Feather',  fruits = { 'orange', 'cherry' }, special = 'honey',  rarity = 'epic', image = 'jar_39', color = '#d2391b', color2 = '#ffc23a', description = 'Rises from the pot in a blaze of colour.' },
    { id = 'nightshade_garden',label = 'Nightshade Garden',fruits = { 'blueberry', 'plum' }, special = 'lavender', rarity = 'epic', image = 'jar_40', color = '#2b1f5e', color2 = '#9a7be0', description = 'Beautiful, floral and mysteriously dark.' },
    { id = 'velvet_vow',       label = 'Velvet Vow',       fruits = { 'strawberry', 'peach' }, special = 'vanilla', rarity = 'epic', image = 'jar_41', color = '#e0485a', color2 = '#f8ddb0', description = 'A promise sealed in cream and berries.' },

    -- ── Legendary (requires golden fruit) ─────────────────────────────────
    { id = 'velora_reserve',   label = 'Velora Reserve',   fruits = { 'strawberry', 'cherry', 'raspberry' }, special = 'golden', rarity = 'legendary', image = 'jar_42', color = '#9e0a2e', color2 = '#ffd36b', description = 'The house masterpiece. Gilded, crimson and unforgettable.' },
    { id = 'eternal_summer',   label = 'Eternal Summer',   fruits = { 'orange', 'peach', 'lemon' },          special = 'golden', rarity = 'legendary', image = 'jar_43', color = '#f5a01a', color2 = '#fff2a0', description = 'A summer that never has to end.' },
    { id = 'nightfall_elixir', label = 'Nightfall Elixir', fruits = { 'blackberry', 'blueberry', 'plum' },   special = 'golden', rarity = 'legendary', image = 'jar_44', color = '#1d0b2e', color2 = '#ffd36b', description = 'Stars stirred into the darkest berries.' },
}

-- Produced by any combination that is not in the book
ExperimentalRecipe = {
    id = 'experimental',
    label = 'Experimental Preserve',
    rarity = 'experimental',
    image = 'jar_experimental',
    color = '#6d5a5a',
    description = 'An unusual blend. Not quite a recipe... yet.',
}
