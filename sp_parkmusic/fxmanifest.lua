fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'SP'
description 'Gentle ambient music around Legion Square park that fades in as players spawn'
version '1.2.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/music/*.ogg',
    'html/music/*.OGG',
    'html/music/*.mp3',
    'html/music/*.MP3',
    'html/music/*.wav',
    'html/music/*.WAV',
    'html/music/*.webm',
    'html/music/*.WEBM',
    'html/music/*.opus',
    'html/music/*.OPUS',
    'html/music/*.flac',
    'html/music/*.FLAC'
}
