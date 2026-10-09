fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'you'
description 'Casino lucky wheel prop giveaway: ox_target sign-up + admin spin, server-synced winner wheel'
version '1.1.0'

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'ox_lib',
    'ox_target',
    'qbx_core',
}
