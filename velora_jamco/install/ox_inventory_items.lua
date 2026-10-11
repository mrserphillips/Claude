-- Velora Jam Co. items for ox_inventory/data/items.lua
-- Paste these entries inside the `return { ... }` table, then copy
-- velora_jamco/web/images/items/*.png into ox_inventory/web/images/

['fruit_orange'] = {
    label = 'Orange',
    weight = 150,
    stack = true,
    close = true,
    description = 'A sun-ripened Grapeseed orange.',
},

['fruit_apple'] = {
    label = 'Apple',
    weight = 150,
    stack = true,
    close = true,
    description = 'Crisp orchard apple.',
},

['fruit_lemon'] = {
    label = 'Lemon',
    weight = 120,
    stack = true,
    close = true,
    description = 'Bright and zesty.',
},

['fruit_cherry'] = {
    label = 'Cherries',
    weight = 40,
    stack = true,
    close = true,
    description = 'A pair of dark, sweet cherries.',
},

['fruit_peach'] = {
    label = 'Peach',
    weight = 150,
    stack = true,
    close = true,
    description = 'Soft and fragrant.',
},

['fruit_strawberry'] = {
    label = 'Strawberry',
    weight = 30,
    stack = true,
    close = true,
    description = 'Plump and glossy.',
},

['fruit_blueberry'] = {
    label = 'Blueberries',
    weight = 30,
    stack = true,
    close = true,
    description = 'A handful of wild blueberries.',
},

['fruit_blackberry'] = {
    label = 'Blackberry',
    weight = 30,
    stack = true,
    close = true,
    description = 'Inky hedgerow blackberry.',
},

['fruit_raspberry'] = {
    label = 'Raspberry',
    weight = 30,
    stack = true,
    close = true,
    description = 'Tart and delicate.',
},

['fruit_plum'] = {
    label = 'Plum',
    weight = 120,
    stack = true,
    close = true,
    description = 'Dusky purple plum.',
},

['golden_fruit'] = {
    label = 'Golden Fruit',
    weight = 200,
    stack = true,
    close = true,
    description = 'A rare, shimmering fruit. Legendary jam-makers prize it.',
},

['jam_sugar'] = {
    label = 'Sugar',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fine caster sugar for preserving.',
},

['jam_jar_empty'] = {
    label = 'Empty Jam Jar',
    weight = 200,
    stack = true,
    close = true,
    description = 'A clean glass jar.',
},

['jam_jar_lid'] = {
    label = 'Jar Lid',
    weight = 20,
    stack = true,
    close = true,
    description = 'Gold lid embossed with a V.',
},

['jam_pectin'] = {
    label = 'Pectin',
    weight = 50,
    stack = true,
    close = true,
    description = 'Helps jam set beautifully.',
},

['jam_cinnamon'] = {
    label = 'Cinnamon Sticks',
    weight = 20,
    stack = true,
    close = true,
    description = 'Warm, sweet spice.',
},

['jam_honey'] = {
    label = 'Wildflower Honey',
    weight = 300,
    stack = true,
    close = true,
    description = 'Golden honey from local hives.',
},

['jam_vanilla'] = {
    label = 'Vanilla Pod',
    weight = 10,
    stack = true,
    close = true,
    description = 'Fragrant vanilla.',
},

['jam_lavender'] = {
    label = 'Lavender',
    weight = 10,
    stack = true,
    close = true,
    description = 'Dried lavender sprigs.',
},

['jam_rose_petals'] = {
    label = 'Rose Petals',
    weight = 10,
    stack = true,
    close = true,
    description = 'Edible rose petals.',
},

['jam_mixing_bowl'] = {
    label = 'Mixing Bowl',
    weight = 600,
    stack = true,
    close = true,
    description = 'Velora ceramic mixing bowl. Never consumed.',
},

['fruit_basket'] = {
    label = 'Fruit Basket',
    weight = 500,
    stack = true,
    close = true,
    description = 'Carry more fruit per picking round.',
},

-- Finished jam: ONE item, everything else lives in metadata (recipe, quality, rarity, batch, maker).
-- metadata.label / metadata.description / metadata.imageurl are set by the server, so every recipe
-- shows its own name, tooltip and jar icon. Jars only stack with jars from the same batch.
['velora_jam'] = {
    label = 'Velora Jam',
    weight = 450,
    stack = true,
    close = true,
    description = 'A jar of Velora Jam Co. preserve.',
},
