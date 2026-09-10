local resourceName = GetCurrentResourceName()
local craftables = {}
local owners = {}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, nested in pairs(value) do result[copy(key)] = copy(nested) end
    return result
end

local function invokingResource()
    return GetInvokingResource() or resourceName
end

local function normaliseItemList(raw, field)
    if type(raw) ~= 'table' or #raw == 0 then return nil, field .. ' items are required' end
    local result = {}
    for _, entry in ipairs(raw) do
        if type(entry) ~= 'table' then return nil, 'invalid ' .. field .. ' item' end
        local item = type(entry.item or entry.name) == 'string' and (entry.item or entry.name):lower() or nil
        local amount = math.floor(tonumber(entry.amount or entry.count) or 0)
        if not item or item == '' or amount < 1 then return nil, 'invalid ' .. field .. ' item' end
        result[#result + 1] = {
            item = item,
            amount = amount,
            metadata = copy(entry.metadata or entry.info or {}),
        }
    end
    return result
end

local function normaliseSkills(raw)
    if raw == nil then return {} end
    if type(raw) ~= 'table' then return nil, 'skills must be a table' end
    local result = {}
    if #raw > 0 then
        for _, entry in ipairs(raw) do
            if type(entry) ~= 'table' then return nil, 'invalid skill requirement' end
            local name = entry.skill or entry.name
            local level = math.floor(tonumber(entry.level) or 0)
            if type(name) ~= 'string' or name == '' or level < 1 then return nil, 'invalid skill requirement' end
            result[#result + 1] = { skill = name, level = level }
        end
    else
        for name, rawLevel in pairs(raw) do
            local level = math.floor(tonumber(rawLevel) or 0)
            if type(name) ~= 'string' or name == '' or level < 1 then return nil, 'invalid skill requirement' end
            result[#result + 1] = { skill = name, level = level }
        end
    end
    table.sort(result, function(a, b) return a.skill < b.skill end)
    return result
end

local function publicCraftable(craftable, context)
    return {
        id = craftable.id,
        label = craftable.label,
        take = copy(craftable.take),
        give = copy(craftable.give),
        skills = copy(craftable.skills),
        context = context,
    }
end

local function checkSkills(source, craftable)
    if #craftable.skills == 0 then return true end
    if GetResourceState('qbskills') ~= 'started' then return false, 'qbskills is required for this craftable' end
    for _, requirement in ipairs(craftable.skills) do
        if not exports.qbskills:isLevel(source, requirement.skill, requirement.level) then
            return false, ('requires %s level %d'):format(requirement.skill, requirement.level)
        end
    end
    return true
end

local function runPreHook(source, craftable, context)
    local skilled, skillErr = checkSkills(source, craftable)
    if not skilled then return false, skillErr end
    if not craftable.pre then return true end
    local ok, result, reason = pcall(craftable.pre, source, publicCraftable(craftable, context))
    if not ok then
        print(('^3[qbcrafting]^7 pre hook failed for %s: %s'):format(craftable.id, tostring(result)))
        return false, 'crafting pre hook failed'
    end
    if result == false then return false, reason or 'crafting cancelled' end
    return true
end

local function qbinventoryRecipe(craftable)
    local ingredients, outputs = {}, {}
    for _, entry in ipairs(craftable.take) do
        ingredients[#ingredients + 1] = { name = entry.item, amount = entry.amount, metadata = copy(entry.metadata) }
    end
    for _, entry in ipairs(craftable.give) do
        outputs[#outputs + 1] = { name = entry.item, amount = entry.amount, metadata = copy(entry.metadata) }
    end
    return {
        label = craftable.label,
        ingredients = ingredients,
        outputs = outputs,
        access = function(source, _, context)
            return runPreHook(source, craftable, context)
        end,
    }
end

---@class QBCraftingItem
---@field item string
---@field amount integer
---@field metadata? table

---@class QBCraftable
---@field id string
---@field label? string
---@field take QBCraftingItem[]
---@field give QBCraftingItem[]
---@field skills? table<string, integer>|table[]
---@field hooks? { pre?: fun(source: integer, data: table): boolean?, post?: fun(source: integer, data: table) }

---@param definition QBCraftable
---@return boolean, string|nil
local function registerCraftable(definition, ownerOverride)
    if type(definition) ~= 'table' then return false, 'craftable must be a table' end
    local id = definition.id
    if type(id) ~= 'string' or id == '' or #id > 96 or not id:match('^[%w_.%-]+$') then
        return false, 'invalid craftable id'
    end
    local owner = ownerOverride or invokingResource()
    if craftables[id] and owners[id] ~= owner then return false, 'craftable is owned by another resource' end
    local take, takeErr = normaliseItemList(definition.take, 'take')
    if not take then return false, takeErr end
    local give, giveErr = normaliseItemList(definition.give, 'give')
    if not give then return false, giveErr end
    local skills, skillErr = normaliseSkills(definition.skills)
    if not skills then return false, skillErr end
    local hooks = definition.hooks or {}
    if type(hooks) ~= 'table' then return false, 'hooks must be a table' end
    if hooks.pre ~= nil and type(hooks.pre) ~= 'function' then return false, 'pre hook must be a function' end
    if hooks.post ~= nil and type(hooks.post) ~= 'function' then return false, 'post hook must be a function' end

    local craftable = {
        id = id,
        label = type(definition.label) == 'string' and definition.label or id,
        take = take,
        give = give,
        skills = skills,
        pre = hooks.pre,
        post = hooks.post,
    }
    local registered, registerErr = exports.qbinventory:RegisterCraftRecipe(id, qbinventoryRecipe(craftable))
    if not registered then return false, registerErr end
    craftables[id], owners[id] = craftable, owner
    return true
end

local function removeCraftable(id)
    if not craftables[id] then return false, 'unknown craftable' end
    if owners[id] ~= invokingResource() then return false, 'not craftable owner' end
    local removed, err = exports.qbinventory:RemoveCraftRecipe(id)
    if not removed then return false, err end
    craftables[id], owners[id] = nil, nil
    return true
end

local function getCraftable(id)
    local craftable = craftables[id]
    return craftable and publicCraftable(craftable) or nil
end

---@param source integer
---@param id string
---@return boolean, string|nil
local function canCraftItem(source, id)
    local craftable = craftables[id]
    if not craftable then return false, 'unknown craftable' end
    local skilled, skillErr = checkSkills(source, craftable)
    if not skilled then return false, skillErr end
    return exports.qbinventory:CanCraftRecipe(source, id)
end

local function shallowlyMatches(actual, required)
    for key, value in pairs(required) do
        if type(value) == 'table' then
            if type(actual[key]) ~= 'table' or not shallowlyMatches(actual[key], value) then return false end
        elseif actual[key] ~= value then return false end
    end
    return true
end

local function itemCount(source, requirement)
    local total = 0
    for _, item in ipairs(exports.qbinventory:GetItemsByName(source, requirement.item) or {}) do
        if shallowlyMatches(item.info or item.metadata or {}, requirement.metadata) then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function craftingRequirements(source, id)
    local craftable = craftables[id]
    if not craftable then return nil, 'unknown craftable' end
    local requirements = {}
    for _, requirement in ipairs(craftable.take) do
        local definition = exports.qbcore:getShared('items', requirement.item)
            or exports.qbcore:getShared('weapons', requirement.item)
        local have = itemCount(source, requirement)
        requirements[#requirements + 1] = {
            item = requirement.item,
            label = definition and definition.label or requirement.item,
            required = requirement.amount,
            have = have,
            satisfied = have >= requirement.amount,
            metadata = copy(requirement.metadata),
        }
    end
    local skills = {}
    for _, requirement in ipairs(craftable.skills) do
        local satisfied = GetResourceState('qbskills') == 'started'
            and exports.qbskills:isLevel(source, requirement.skill, requirement.level)
        skills[#skills + 1] = {
            skill = requirement.skill,
            level = requirement.level,
            satisfied = satisfied == true,
        }
    end
    return requirements, skills
end

---@param source integer
---@param id string
---@param context? table
---@return boolean, table|string
local function craftItem(source, id, context)
    local craftable = craftables[id]
    if not craftable then return false, 'unknown craftable' end
    local crafted, result = exports.qbinventory:CraftItem(source, id, context)
    if not crafted then return false, result end
    local data = publicCraftable(craftable, context)
    if craftable.post then
        local ok, err = pcall(craftable.post, source, data)
        if not ok then
            print(('^3[qbcrafting]^7 post hook failed for %s after commit: %s'):format(id, tostring(err)))
        end
    end
    TriggerEvent('qbcrafting:server:crafted', source, id, data)
    return true, result
end

QB.callback.register('qbcrafting:server:craftability', function(source, id)
    local canCraft, reason = canCraftItem(source, id)
    local requirements, skills = craftingRequirements(source, id)
    return {
        canCraft = canCraft,
        reason = reason,
        requirements = requirements or {},
        skills = skills or {},
    }
end, { rateLimit = { max = 10, window = 5000 } })

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == resourceName then return end
    for id, owner in pairs(owners) do
        if owner == stoppedResource then
            exports.qbinventory:RemoveCraftRecipe(id)
            craftables[id], owners[id] = nil, nil
        end
    end
end)

exports('RegisterCraftable', registerCraftable)
exports('RemoveCraftable', removeCraftable)
exports('GetCraftable', getCraftable)
exports('GetCraftingRequirements', craftingRequirements)
exports('CanCraftItem', canCraftItem)
exports('CraftItem', craftItem)

for key, definition in pairs(Config.craftables or {}) do
    local configured = copy(definition)
    if type(key) == 'string' and configured.id == nil then configured.id = key end
    local registered, err = registerCraftable(configured, resourceName)
    if not registered then
        print(('^1[qbcrafting]^7 failed to register configured craftable %s: %s'):format(tostring(configured.id or key), tostring(err)))
    end
end
