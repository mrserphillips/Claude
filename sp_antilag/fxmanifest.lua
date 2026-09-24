fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'SP'
description 'Reactive mechanic-fitted anti-lag / rapid backfire system'
version '4.6.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'

ui_page 'html/index.html'
files { 'html/index.html' }

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
