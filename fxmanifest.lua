fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Crafting stations and recipes, built and edited in game'
version '1.0.0'

dependency 'qblib'
dependency 'qbcore'
dependency 'qbsql'

shared_scripts {
    '@qblib/init.lua',
    '@qbcore/init.lua',
    '@qbsql/init.lua',
    'shared/constants.lua',
    'shared/config.lua',
}

client_scripts {
    'client/_functions.lua',
    'client/craft.lua',
    'client/creator.lua',
}

-- Order matters here: each file uses the ones before it.
server_scripts {
    'server/_functions.lua',
    'server/skills.lua',
    'server/rules.lua',
    'server/data.lua',
    'server/creator.lua',
    'server/craft.lua',
    'server/logs.lua',
}
