fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'SP'
description 'Gentle ambient music around Legion Square park that fades in as players spawn'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/music/*.ogg',
    'html/music/*.mp3'
}
