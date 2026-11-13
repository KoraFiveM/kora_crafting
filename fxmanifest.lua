fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Crafting stations and recipes, built and edited in game'
author 'Kora'
version '0.2.1'

dependency 'kora_lib'
dependency 'kora_core'
dependency 'kora_sql'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    'shared/constants.lua',
    'shared/config.lua',
}

files { 'locales/*.lua' }

client_scripts {
    'client/_functions.lua',
    'client/craft.lua',
    'client/creator.lua',
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks.lua'
}

-- Order matters here: each file uses the ones before it.
server_scripts {
    '@kora_sql/init.lua',
    'server/schema.lua',
    'server/_functions.lua',
    'server/skills.lua',
    'server/rules.lua',
    'server/data.lua',
    'server/creator.lua',
    'server/craft.lua',
    'server/logs.lua',
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
