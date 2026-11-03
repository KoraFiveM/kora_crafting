fx_version 'cerulean'
game 'gta5'
lua54 'yes'
-- Keep the legacy resource name resolvable for exports['qbcrafting'] callers.
provide 'qbcrafting'
description 'Crafting stations and recipes, built and edited in game'
version '1.0.0'

dependency 'kora_lib'
dependency 'kora_core'
dependency 'kora_sql'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    '@kora_sql/init.lua',
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
    'server/schema.lua',
    'server/_functions.lua',
    'server/skills.lua',
    'server/rules.lua',
    'server/data.lua',
    'server/creator.lua',
    'server/craft.lua',
    'server/logs.lua',
}
