-- Run from the resource directory: lua test/schema.lua
Kora = { sql = { NULL = '\0qbsql:null\0' } }
dofile('server/schema.lua')

local declared = {}
for _, spec in ipairs(QBCraftingSchema) do declared[spec.name] = spec end
for _, name in ipairs({ 'kora_crafting_recipes', 'kora_crafting_stations', 'kora_crafting_logs' }) do
    assert(declared[name], name .. ' is declared')
    assert(declared[name].primary[1] == 'id', name .. ' keeps its id primary key')
end
assert(#QBCraftingSchema == 3, 'no undeclared tables')

local manifest = assert(io.open('fxmanifest.lua')):read('a')
assert(manifest:find("'server/schema.lua'", 1, true), 'manifest loads the schema')
assert(not manifest:find('qbcrafting.sql', 1, true), 'manifest no longer ships the sql file')
print('qbcrafting: schema declares its tables')
