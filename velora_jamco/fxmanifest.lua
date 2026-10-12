fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'velora_jamco'
author 'Velora RP'
description 'Velora Jam Co. - fruit harvesting, jam making, recipe discovery and NPC selling'
version '1.2.3'

dependencies {
    '/onesync',
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/nui.lua',
    'client/main.lua',
    'client/harvest.lua',
    'client/kitchen.lua',
    'client/selling.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/recipes.lua',
    'server/main.lua',
    'server/business.lua',
    'server/harvest.lua',
    'server/crafting.lua',
    'server/selling.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/fonts/*.woff2',
    'web/images/items/*.png',
    'web/images/jams/*.png',
    'web/images/ui/*.png',
    -- FiveM does not support wildcards in folder names, so each art folder is listed.
    -- If you add art to a new folder (e.g. seal/ or a background .jpg), add a line for it here.
    'web/images/minigames/*.jpg',
    'web/images/minigames/fruit/*.png',
    'web/images/minigames/heat/*.png',
    'web/images/minigames/stir/*.png',
    'web/images/minigames/fill/*.png',
    'web/images/minigames/prepare/*.png',
    'web/images/minigames/harvest/*.png',
}
