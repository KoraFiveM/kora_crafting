fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbcrafting'
author 'qbcore2'
version '0.2.0'
description 'Server-authoritative crafting recipes, benches, and access rules'

dependency 'qblib'
dependency 'qbcore'
dependency 'qbinventory'

shared_script '@qblib/init.lua'

server_scripts {
    'config.lua',
    'server/main.lua',
    'server/areas.lua',
}

client_script 'client/main.lua'
