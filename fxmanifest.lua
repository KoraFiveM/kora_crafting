fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbcrafting'
author 'qbcore2'
version '0.1.0'
description 'Server-authoritative, export-driven crafting recipes'

dependency 'qblib'
dependency 'qbcore'
dependency 'qbinventory'

shared_script '@qblib/init.lua'

server_scripts {
    'config.lua',
    'server/main.lua',
}

client_script 'client/main.lua'
