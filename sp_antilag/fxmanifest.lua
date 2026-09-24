fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'SP'
description 'Mechanic-fitted anti-lag / 2-step with launch control and a tuning panel'
version '5.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/audio.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'qbx_core'
}
