local H = dofile('test/harness.lua')

local registeredExports, eventHandlers = {}, {}
local invoking = 'recipe-owner'
local recipes, inventory = {}, {
    { name = 'wood', amount = 3, info = {} },
}
local skillLevel, committed = 10, 0

local inventoryExports = {}
function inventoryExports.RegisterCraftRecipe(_, id, recipe) recipes[id] = recipe return true end
function inventoryExports.RemoveCraftRecipe(_, id) recipes[id] = nil return true end
function inventoryExports.CanCraftRecipe(_, _, id)
    local recipe = recipes[id]
    local needed = recipe.ingredients[1].amount
    return inventory[1].amount >= needed, 'missing crafting ingredient: wood'
end
function inventoryExports.CraftItem(_, source, id, context)
    local recipe = recipes[id]
    local allowed, reason = recipe.access(source, recipe, context)
    if allowed == false then return false, reason end
    if inventory[1].amount < recipe.ingredients[1].amount then return false, 'missing crafting ingredient: wood' end
    inventory[1].amount = inventory[1].amount - recipe.ingredients[1].amount
    committed = committed + 1
    return true, recipe.outputs
end
function inventoryExports.GetItemsByName(_, _, name)
    return name == 'wood' and inventory or {}
end

local coreExports = {}
function coreExports.getShared(_, _, name) return { name = name, label = name == 'wood' and 'Wood' or name } end

local skillExports = {}
function skillExports.isLevel(_, _, _, level) return skillLevel >= level end

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

dofile('server/main.lua')

local preResult, postResult, postSawCommit
local ok, err = registeredExports.RegisterCraftable({
    id = 'board',
    take = { { item = 'wood', amount = 2 } },
    give = { { item = 'board', amount = 1 }, { item = 'sawdust', amount = 1 } },
    skills = { crafting = 5 },
    hooks = {
        pre = function() return preResult end,
        post = function() postResult = true postSawCommit = committed end,
    },
})
H.equal(ok, true, err or 'recipe registers')
H.equal(#recipes.board.outputs, 2, 'all outputs reach the atomic inventory recipe')
H.equal(registeredExports.CanCraftItem(7, 'board'), true, 'server feasibility checks items and skills')

preResult = false
H.equal(registeredExports.CraftItem(7, 'board'), false, 'exact false from pre hook cancels')
H.equal(inventory[1].amount, 3, 'cancelled pre hook changes no ingredients')
H.equal(committed, 0, 'cancelled pre hook gives no output')

preResult = nil
H.equal(registeredExports.CraftItem(7, 'board'), true, 'nil pre-hook result permits crafting')
H.equal(inventory[1].amount, 1, 'successful craft consumes ingredients')
H.equal(postResult, true, 'post hook runs after success')
H.equal(postSawCommit, 1, 'post hook observes the committed transaction')

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

H.finish()
