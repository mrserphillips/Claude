fx_version 'cerulean'
game 'gta5'

name 'missys_job_creator'
author "Missy's House"
description 'In-city QBX job, world point, NPC and business creator'
version '2.0.11'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/styles.css',
    'web/state.js',
    'web/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua',
    'shared/point_types.lua',
    'shared/validation.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/placement.lua',
    'client/interactions.lua',
    'client/point_actions.lua',
    'client/points.lua',
    'client/blips.lua',
    'client/fleet.lua',
    'client/npcs.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/permissions.lua',
    'server/migrations.lua',
    'server/schema.lua',
    'server/persistence.lua',
    'server/payments.lua',
    'server/revenue.lua',
    'server/jobs.lua',
    'server/points.lua',
    'server/point_actions.lua',
    'server/blips.lua',
    'server/fleet.lua',
    'server/job_packages.lua',
    'server/integrations.lua',
    'server/npcs.lua',
    'server/businesses.lua',
    'server/shops.lua',
    'server/selftest.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}
