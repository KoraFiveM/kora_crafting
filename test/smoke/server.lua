local H = dofile('test/harness.lua')

local registeredExports, eventHandlers = {}, {}
local invoking = 'recipe-owner'
local recipes, inventory = {}, {
    { name = 'wood', amount = 3, info = {} },
}
local skillLevel, committed, awardedXp = 10, 0, 0

local inventoryExports = {}
function inventoryExports.RegisterCraftRecipe(_, id, recipe) recipes[id] = recipe return true end
function inventoryExports.RemoveCraftRecipe(_, id) recipes[id] = nil return true end
function inventoryExports.CanCraftRecipe(_, _, id, amount)
    local recipe = recipes[id]
    local needed = recipe.ingredients[1].amount * (amount or 1)
    return inventory[1].amount >= needed, 'missing crafting ingredient: wood'
end
function inventoryExports.CraftItem(_, source, id, context, amount)
    local recipe = recipes[id]
    amount = amount or 1
    local allowed, reason = recipe.access(source, recipe, context)
    if allowed == false then return false, reason end
    if inventory[1].amount < recipe.ingredients[1].amount * amount then return false, 'missing crafting ingredient: wood' end
    inventory[1].amount = inventory[1].amount - recipe.ingredients[1].amount * amount
    committed = committed + 1
    local outputs = {}
    for index, output in ipairs(recipe.outputs) do
        outputs[index] = { name = output.name, amount = output.amount * amount, metadata = output.metadata }
    end
    return true, outputs
end
function inventoryExports.GetItemsByName(_, _, name)
    return name == 'wood' and inventory or {}
end

local coreExports = {}
function coreExports.getShared(_, _, name) return { name = name, label = name == 'wood' and 'Wood' or name } end

local skillExports = {}
function skillExports.isLevel(_, _, _, level) return skillLevel >= level end
function skillExports.addRep(_, _, _, amount) awardedXp = awardedXp + amount return true end

local playerData = {
    job = { name = 'mechanic', grade = { level = 2 }, onduty = true },
    gang = { name = 'none', grade = { level = 1 } },
}
function coreExports.getPlayer() return playerData end

exports = setmetatable({ qbinventory = inventoryExports, qbcore = coreExports, qbskills = skillExports }, {
    __call = function(_, name, callback) registeredExports[name] = callback end,
})
Config = { craftables = {} }
QB = { callback = { register = function(name, callback) registeredExports[name] = callback end } }
GetCurrentResourceName = function() return 'qbcrafting' end
GetInvokingResource = function() return invoking end
GetResourceState = function(name) return name == 'qbskills' and 'started' or 'missing' end
AddEventHandler = function(name, callback) eventHandlers[name] = callback end
TriggerEvent = function() end
TriggerClientEvent = function() end
GetPlayerPed = function() return 77 end
local playerCoords = { x = 10, y = 20, z = 30 }
GetEntityCoords = function() return playerCoords end

dofile('server/main.lua')

exports.qbcrafting = setmetatable({}, {
    __index = function(_, name)
        return function(_, ...) return registeredExports[name](...) end
    end,
})

-- FiveM vectors report `vector3`/`vector4` from type(), unlike ordinary Lua
-- tables. Tag test values so the standalone harness exercises that contract.
local luaType = type
type = function(value)
    local metatable = getmetatable(value)
    return metatable and metatable.vectorType or luaType(value)
end
local function nativeVector(kind, x, y, z, w)
    return setmetatable({ x = x, y = y, z = z, w = w }, { vectorType = kind })
end

local preResult, postResult, postSawCommit
local ok, err = registeredExports.RegisterCraftable({
    id = 'board',
    take = { { item = 'wood', amount = 2 } },
    give = { { item = 'board', amount = 1 }, { item = 'sawdust', amount = 1 } },
    skills = { crafting = 5 },
    skillRewards = { crafting = 15 },
    hooks = {
        pre = function() return preResult end,
        post = function() postResult = true postSawCommit = committed end,
    },
})
H.equal(ok, true, err or 'recipe registers')
H.equal(#recipes.board.outputs, 2, 'all outputs reach the atomic inventory recipe')
H.equal(registeredExports.CanCraftItem(7, 'board'), true, 'server feasibility checks items and skills')

preResult = false
H.equal(registeredExports.CanCraftItem(7, 'board'), false, 'feasibility includes the dynamic pre-hook policy')
H.equal(registeredExports.CraftItem(7, 'board'), false, 'exact false from pre hook cancels')
H.equal(inventory[1].amount, 3, 'cancelled pre hook changes no ingredients')
H.equal(committed, 0, 'cancelled pre hook gives no output')

preResult = nil
H.equal(registeredExports.CraftItem(7, 'board'), true, 'nil pre-hook result permits crafting')
H.equal(inventory[1].amount, 1, 'successful craft consumes ingredients')
H.equal(postResult, true, 'post hook runs after success')
H.equal(postSawCommit, 1, 'post hook observes the committed transaction')
H.equal(awardedXp, 15, 'successful craft awards its declarative skill XP')

inventory[1].amount = 6
H.equal(registeredExports.CraftItem(7, 'board', nil, 3), true, 'batch crafting is accepted')
H.equal(inventory[1].amount, 0, 'batch crafting consumes every scaled ingredient in one commit')
H.equal(awardedXp, 60, 'batch crafting scales skill rewards')

inventory[1].amount = 1
local requirements, skills = registeredExports.GetCraftingRequirements(7, 'board')
H.equal(requirements[1].required, 2, 'requirements expose required amount')
H.equal(requirements[1].have, 1, 'requirements expose current amount')
H.equal(requirements[1].satisfied, false, 'requirements expose item satisfaction')
H.equal(skills[1].satisfied, true, 'requirements expose skill satisfaction')

skillLevel = 1
H.equal(registeredExports.CanCraftItem(7, 'board'), false, 'declarative skill requirement gates feasibility')

invoking = 'other-owner'
H.equal(registeredExports.RegisterCraftable({
    id = 'board', take = { { item = 'wood', amount = 1 } }, give = { { item = 'board', amount = 1 } },
}), false, 'another resource cannot replace an owned recipe')

dofile('server/areas.lua')

invoking = 'area-owner'
skillLevel = 10
H.equal(registeredExports.RegisterCraftingArea({
    id = 'mechanic_bench',
    recipes = { 'board' },
    model = 'prop_tool_bench02',
    coords = nativeVector('vector4', 10, 20, 30, 90),
    rules = { jobs = { mechanic = 2 }, onDuty = true, skills = { crafting = 5 } },
}), true, 'model-backed crafting area registers')
H.equal(registeredExports.CanUseCraftingArea(7, 'mechanic_bench'), true,
    'area allows a nearby on-duty player with the required job grade and skill')
local snapshot = registeredExports['qbcrafting:server:areaSnapshotRequested'](7, 'mechanic_bench')
H.equal(snapshot.label, 'mechanic_bench', 'area snapshot exposes station presentation data')
H.equal(snapshot.recipes[1].requirements[1].have, 1, 'area snapshot includes live ingredient counts')
H.equal(snapshot.recipes[1].canCraft, false, 'area snapshot reports current craftability')
H.equal(registeredExports.RegisterCraftingArea({
    id = 'native_box',
    recipes = { 'board' },
    zone = {
        type = 'box',
        coords = nativeVector('vector3', 10, 20, 30),
        size = nativeVector('vector3', 3, 3, 3),
    },
}), true, 'native FiveM vectors are accepted for box coordinates and size')

playerData.job.onduty = false
H.equal(registeredExports.CanUseCraftingArea(7, 'mechanic_bench'), false, 'area duty rule is enforced')
playerData.job.onduty = true
playerCoords = { x = 100, y = 200, z = 300 }
H.equal(registeredExports.CanUseCraftingArea(7, 'mechanic_bench'), false, 'area proximity is server-authoritative')
playerCoords = { x = 10, y = 20, z = 30 }

H.equal(registeredExports.RegisterCraftingArea({
    id = 'poly_bench',
    recipes = { 'board' },
    zone = {
        type = 'poly',
        points = { { x = 8, y = 18, z = 29 }, { x = 12, y = 18, z = 29 }, { x = 12, y = 22, z = 29 } },
        thickness = 3,
    },
}), true, 'existing-world poly crafting area registers')
H.equal(registeredExports.CanUseCraftingArea(7, 'poly_bench'), true, 'poly footprint and height contain the player')
H.equal(registeredExports.RegisterCraftingArea({
    id = 'bad_poly',
    recipes = { 'board' },
    zone = {
        type = 'poly',
        points = { { x = 8, y = 18, z = 29 }, { x = 12, y = 18, z = 29 }, { x = 12, y = 22, z = 29 } },
        thickness = 'wide',
    },
}), false, 'invalid poly thickness is rejected without crashing')

playerData.gang = { name = 'ballas', grade = { level = 2 } }
H.equal(registeredExports.RegisterCraftingArea({
    id = 'gang_bench',
    recipes = { 'board' },
    zone = { type = 'sphere', coords = { x = 10, y = 20, z = 30 }, radius = 2 },
    rules = { gangs = { ballas = 2 } },
}), true, 'gang-restricted sphere crafting area registers')
H.equal(registeredExports.CanUseCraftingArea(7, 'gang_bench'), true, 'area gang grade rule is enforced')
playerData.gang.name = 'vagos'
H.equal(registeredExports.CanUseCraftingArea(7, 'gang_bench'), false, 'different gang cannot use the area')
playerData.gang.name = 'none'

inventory[1].amount = 3
H.equal(registeredExports.CraftAtArea(7, 'mechanic_bench', 'not_offered'), false,
    'area craft rejects a recipe that the bench does not offer')
H.equal(registeredExports.CraftAtArea(7, 'mechanic_bench', 'board'), true,
    'nearby authorized player can commit an offered recipe')

inventory[1].amount = 4
local batchCrafted, _, _, confirmation = registeredExports['qbcrafting:server:areaCraftRequested'](
    7, 'mechanic_bench', 'board', 2)
H.equal(batchCrafted, true, 'area callback accepts a server-bounded craft amount')
H.equal(confirmation.removed[1].amount, 4, 'area callback confirms the scaled ingredient removal')
H.equal(confirmation.received[1].amount, 2, 'area callback confirms the scaled output grant')
H.equal(registeredExports['qbcrafting:server:areaCraftRequested'](7, 'mechanic_bench', 'board', 'many'), false,
    'area callback rejects a malformed crafting amount')

invoking = 'different-owner'
H.equal(registeredExports.RemoveCraftingArea('mechanic_bench'), false, 'another resource cannot remove an owned area')

H.finish()
