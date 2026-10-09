fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'velora_starterpack'
author 'Velora City'
description 'Velora City starter pack — choose your path (Qbox / ox_inventory / oxmysql)'
version '1.2.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua', -- server-only: rewards & settings are never sent to clients
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'qbx_core',
    'qbx_vehicles',
}
