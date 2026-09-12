local resourceName = GetCurrentResourceName()
local areas = {}
local owners = {}

local copy = QB.util.deepClone

local function invokingResource()
    return GetInvokingResource() or resourceName
end

local function validId(value)
    return type(value) == 'string' and value ~= '' and #value <= 96 and value:match('^[%w_.%-]+$') ~= nil
end

local function coords(raw, field)
    local rawType = type(raw)
    if (rawType ~= 'table' and rawType ~= 'vector3' and rawType ~= 'vector4')
        or type(raw.x) ~= 'number' or type(raw.y) ~= 'number' or type(raw.z) ~= 'number' then
        return nil, field .. ' coordinates must be vector-like'
    end
    return { x = raw.x + 0.0, y = raw.y + 0.0, z = raw.z + 0.0, w = tonumber(raw.w or raw.heading) }
end

local function positiveNumber(value, fallback)
    value = tonumber(value) or fallback
    return value and value > 0 and value or nil
end

local function normaliseZone(raw)
    if type(raw) ~= 'table' then return nil, 'area needs a model or zone' end
    local kind = raw.type
    if kind ~= 'box' and kind ~= 'sphere' and kind ~= 'poly' then return nil, 'zone type must be box, sphere, or poly' end

    if kind == 'sphere' then
        local center, err = coords(raw.coords, 'sphere')
        local radius = positiveNumber(raw.radius)
        if not center then return nil, err end
        if not radius then return nil, 'sphere radius must be positive' end
        return { type = kind, coords = center, radius = radius, debug = raw.debug == true }
    end

    if kind == 'box' then
        local center, err = coords(raw.coords, 'box')
        local sizeType = type(raw.size)
        local size = (sizeType == 'table' or sizeType == 'vector3' or sizeType == 'vector4') and raw.size or nil
        if not center then return nil, err end
        if not size or not positiveNumber(size.x) or not positiveNumber(size.y) or not positiveNumber(size.z) then
            return nil, 'box size must contain positive x, y, and z values'
        end
        return {
            type = kind,
            coords = center,
            size = { x = size.x + 0.0, y = size.y + 0.0, z = size.z + 0.0 },
            rotation = tonumber(raw.rotation) or 0.0,
            debug = raw.debug == true,
        }
    end

    if type(raw.points) ~= 'table' or #raw.points < 3 then return nil, 'poly zone needs at least three points' end
    local points, lowest, highest = {}, math.huge, -math.huge
    for index, point in ipairs(raw.points) do
        local clean, err = coords(point, ('poly point %d'):format(index))
        if not clean then return nil, err end
        points[#points + 1] = clean
        lowest, highest = math.min(lowest, clean.z), math.max(highest, clean.z)
    end
    local thickness = raw.thickness == nil and nil or positiveNumber(raw.thickness)
    if raw.thickness ~= nil and not thickness then return nil, 'poly thickness must be positive' end
    local minZ = tonumber(raw.minZ) or lowest
    local maxZ = tonumber(raw.maxZ) or (thickness and lowest + thickness or highest)
    if maxZ <= minZ then return nil, 'poly zone height must be positive' end
    return { type = kind, points = points, minZ = minZ, maxZ = maxZ, debug = raw.debug == true }
end

local function normaliseLocation(definition)
    if definition.model ~= nil then
        if type(definition.model) ~= 'string' and type(definition.model) ~= 'number' then
            return nil, 'area model must be a string or hash'
        end
        local position, err = coords(definition.coords, 'model')
        if not position then return nil, err end
        local radius = positiveNumber(definition.radius, 2.5)
        if not radius then return nil, 'model interaction radius must be positive' end
        return {
            type = 'model',
            model = definition.model,
            coords = position,
            radius = radius,
            streamRadius = positiveNumber(definition.streamRadius, 75.0) or 75.0,
        }
    end
    return normaliseZone(definition.zone)
end

local function normaliseAffiliations(raw, field)
    if raw == nil then return {} end
    if type(raw) == 'string' then return { [raw] = 1 } end
    if type(raw) ~= 'table' then return nil, field .. ' must be a string, array, or grade map' end
    local result = {}
    if #raw > 0 then
        for _, name in ipairs(raw) do
            if type(name) ~= 'string' or name == '' then return nil, 'invalid ' .. field .. ' entry' end
            result[name] = 1
        end
    else
        for name, rawGrade in pairs(raw) do
            local grade = math.floor(tonumber(rawGrade) or 0)
            if type(name) ~= 'string' or name == '' or grade < 1 then return nil, 'invalid ' .. field .. ' entry' end
            result[name] = grade
        end
    end
    return result
end

local function normaliseSkills(raw)
    if raw == nil then return {} end
    if type(raw) ~= 'table' then return nil, 'area skills must be a table' end
    local result = {}
    for skill, rawLevel in pairs(raw) do
        local level = math.floor(tonumber(rawLevel) or 0)
        if type(skill) ~= 'string' or skill == '' or level < 1 then return nil, 'invalid area skill requirement' end
        result[skill] = level
    end
    return result
end

local function publicArea(area)
    return {
        id = area.id,
        label = area.label,
        recipes = copy(area.recipes),
        location = copy(area.location),
        rules = copy(area.rules),
    }
end

local function affiliationAllowed(current, allowed)
    if not next(allowed) then return true end
    if type(current) ~= 'table' then return false end
    local minimum = allowed[current.name]
    return minimum ~= nil and type(current.grade) == 'table' and (tonumber(current.grade.level) or 0) >= minimum
end

local function checkAccess(source, area)
    local player = exports.qbcore:getPlayer(source)
    if type(player) ~= 'table' then return false, 'player has no active character' end
    if not affiliationAllowed(player.job, area.rules.jobs) then return false, 'your job cannot use this bench' end
    if area.rules.onDuty and (type(player.job) ~= 'table' or player.job.onduty ~= true) then
        return false, 'you must be on duty to use this bench'
    end
    if not affiliationAllowed(player.gang, area.rules.gangs) then return false, 'your gang cannot use this bench' end
    if next(area.rules.skills) and GetResourceState('qbskills') ~= 'started' then
        return false, 'qbskills is required to use this bench'
    end
    for skill, level in pairs(area.rules.skills) do
        if not exports.qbskills:isLevel(source, skill, level) then
            return false, ('requires %s level %d'):format(skill, level)
        end
    end
    if area.canUse then
        local ok, allowed, reason = pcall(area.canUse, source, publicArea(area))
        if not ok then
            print(('^3[qbcrafting]^7 canUse hook failed for %s: %s'):format(area.id, tostring(allowed)))
            return false, 'crafting area policy failed'
        end
        if allowed == false then return false, reason or 'you cannot use this bench' end
    end
    return true
end

local function pointInPoly(point, points)
    local inside, previous = false, #points
    for index = 1, #points do
        local a, b = points[index], points[previous]
        if ((a.y > point.y) ~= (b.y > point.y))
            and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x then
            inside = not inside
        end
        previous = index
    end
    return inside
end

local function contains(location, point)
    if location.type == 'model' or location.type == 'sphere' then
        local center = location.coords
        local dx, dy, dz = point.x - center.x, point.y - center.y, point.z - center.z
        local radius = location.radius
        return dx * dx + dy * dy + dz * dz <= radius * radius
    end
    if location.type == 'poly' then
        return point.z >= location.minZ and point.z <= location.maxZ and pointInPoly(point, location.points)
    end

    local center, size = location.coords, location.size
    local radians = math.rad(-(location.rotation or 0.0))
    local cosRotation, sinRotation = math.cos(radians), math.sin(radians)
    local dx, dy = point.x - center.x, point.y - center.y
    local localX = dx * cosRotation - dy * sinRotation
    local localY = dx * sinRotation + dy * cosRotation
    return math.abs(localX) <= size.x * 0.5 and math.abs(localY) <= size.y * 0.5
        and math.abs(point.z - center.z) <= size.z * 0.5
end

local function playerInside(source, area)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return contains(area.location, GetEntityCoords(ped))
end

---@class QBCraftingAreaRules
---@field jobs? string|string[]|table<string, integer>
---@field gangs? string|string[]|table<string, integer>
---@field skills? table<string, integer>
---@field onDuty? boolean
---@field canUse? fun(source: integer, area: table):(boolean?, string?)

---@class QBCraftingArea
---@field id string
---@field label? string
---@field recipes string[]
---@field model? string|integer
---@field coords? vector4|table
---@field radius? number
---@field streamRadius? number
---@field zone? table
---@field rules? QBCraftingAreaRules

---@param definition QBCraftingArea
---@return boolean, string|nil
local function registerCraftingArea(definition, ownerOverride)
    if type(definition) ~= 'table' then return false, 'crafting area must be a table' end
    if not validId(definition.id) then return false, 'invalid crafting area id' end
    local owner = ownerOverride or invokingResource()
    if areas[definition.id] and owners[definition.id] ~= owner then return false, 'crafting area is owned by another resource' end
    if type(definition.recipes) ~= 'table' or #definition.recipes == 0 then return false, 'crafting area needs recipes' end

    local recipes, recipeIds = {}, {}
    for _, id in ipairs(definition.recipes) do
        if not validId(id) or recipeIds[id] then return false, 'invalid or duplicate crafting area recipe' end
        local craftable = exports.qbcrafting:GetCraftable(id)
        if not craftable then return false, 'unknown craftable: ' .. tostring(id) end
        recipeIds[id] = true
        recipes[#recipes + 1] = { id = id, label = craftable.label }
    end
    local location, locationErr = normaliseLocation(definition)
    if not location then return false, locationErr end
    local rawRules = definition.rules or {}
    if type(rawRules) ~= 'table' then return false, 'area rules must be a table' end
    local jobs, jobsErr = normaliseAffiliations(rawRules.jobs, 'jobs')
    if not jobs then return false, jobsErr end
    local gangs, gangsErr = normaliseAffiliations(rawRules.gangs, 'gangs')
    if not gangs then return false, gangsErr end
    local skills, skillsErr = normaliseSkills(rawRules.skills)
    if not skills then return false, skillsErr end
    if rawRules.canUse ~= nil and type(rawRules.canUse) ~= 'function' then return false, 'canUse rule must be a function' end

    local area = {
        id = definition.id,
        label = type(definition.label) == 'string' and definition.label or definition.id,
        recipes = recipes,
        recipeIds = recipeIds,
        location = location,
        rules = { jobs = jobs, gangs = gangs, skills = skills, onDuty = rawRules.onDuty == true },
        canUse = rawRules.canUse,
    }
    areas[area.id], owners[area.id] = area, owner
    TriggerClientEvent('qbcrafting:client:areaRegistered', -1, publicArea(area))
    return true
end

local function removeCraftingArea(id)
    if not areas[id] then return false, 'unknown crafting area' end
    if owners[id] ~= invokingResource() then return false, 'not crafting area owner' end
    areas[id], owners[id] = nil, nil
    TriggerClientEvent('qbcrafting:client:areaRemoved', -1, id)
    return true
end

local function getCraftingArea(id)
    local area = areas[id]
    return area and publicArea(area) or nil
end

local function allPublicAreas()
    local result = {}
    for _, area in pairs(areas) do result[#result + 1] = publicArea(area) end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

local function outputData(entry)
    local definition = exports.qbcore:getShared('items', entry.item)
        or exports.qbcore:getShared('weapons', entry.item)
    return {
        item = entry.item,
        label = definition and definition.label or entry.item,
        amount = entry.amount,
        metadata = copy(entry.metadata),
        image = definition and definition.imageUrl or nil,
        description = definition and definition.description or nil,
    }
end

local function areaSnapshot(source, id)
    local area = type(id) == 'string' and areas[id] or nil
    if not area then return nil, 'unknown crafting area' end
    if not playerInside(source, area) then return nil, 'you are too far from this crafting area' end
    local allowed, accessErr = checkAccess(source, area)
    if not allowed then return nil, accessErr end

    local recipes = {}
    for _, offered in ipairs(area.recipes) do
        local craftable = exports.qbcrafting:GetCraftable(offered.id)
        if craftable then
            local requirements, skills = exports.qbcrafting:GetCraftingRequirements(source, offered.id)
            local canCraft, reason = exports.qbcrafting:CanCraftItem(source, offered.id, { area = area.id })
            local maxCraftAmount = 0
            if canCraft then
                local upper = 100
                for _, requirement in ipairs(requirements or {}) do
                    upper = math.min(upper, math.floor(requirement.have / requirement.required))
                end
                local low = 1
                while low <= upper do
                    local middle = math.floor((low + upper) / 2)
                    if exports.qbinventory:CanCraftRecipe(source, offered.id, middle) then
                        maxCraftAmount = middle
                        low = middle + 1
                    else
                        upper = middle - 1
                    end
                end
            end
            local outputs = {}
            for _, entry in ipairs(craftable.give) do outputs[#outputs + 1] = outputData(entry) end
            local failureReason
            if not canCraft then failureReason = reason end
            recipes[#recipes + 1] = {
                id = craftable.id,
                label = craftable.label,
                canCraft = canCraft == true,
                reason = failureReason,
                requirements = requirements or {},
                skills = skills or {},
                outputs = outputs,
                skillRewards = copy(craftable.skillRewards),
                maxCraftAmount = maxCraftAmount,
            }
        end
    end
    return { id = area.id, label = area.label, recipes = recipes }
end

local function craftAtArea(source, areaId, recipeId, amount)
    local area = type(areaId) == 'string' and areas[areaId] or nil
    if not area then return false, 'unknown crafting area' end
    if type(recipeId) ~= 'string' or not area.recipeIds[recipeId] then return false, 'recipe is not offered here' end
    if not playerInside(source, area) then return false, 'you are too far from this crafting area' end
    local allowed, accessErr = checkAccess(source, area)
    if not allowed then return false, accessErr end
    return exports.qbcrafting:CraftItem(source, recipeId, { area = area.id }, amount)
end

QB.callback.register('qbcrafting:server:areasRequested', function()
    return allPublicAreas()
end, { rateLimit = { max = 4, window = 5000 } })

QB.callback.register('qbcrafting:server:areaSnapshotRequested', function(source, areaId)
    return areaSnapshot(source, areaId)
end, { rateLimit = { max = 10, window = 5000 } })

QB.callback.register('qbcrafting:server:areaCraftRequested', function(source, areaId, recipeId, amount)
    local number = amount == nil and 1 or tonumber(amount)
    if not number or number ~= number or number == math.huge or number == -math.huge or number % 1 ~= 0 then
        return false, 'invalid crafting amount', areaSnapshot(source, areaId)
    end
    amount = math.floor(number)
    local craftable = type(recipeId) == 'string' and exports.qbcrafting:GetCraftable(recipeId) or nil
    local crafted, result = craftAtArea(source, areaId, recipeId, amount)
    local snapshot = areaSnapshot(source, areaId)
    if not crafted then return false, result, snapshot end
    local confirmation = { removed = {}, received = {} }
    for _, entry in ipairs(craftable.take) do
        confirmation.removed[#confirmation.removed + 1] = outputData({
            item = entry.item, amount = entry.amount * amount, metadata = entry.metadata,
        })
    end
    for _, entry in ipairs(craftable.give) do
        confirmation.received[#confirmation.received + 1] = outputData({
            item = entry.item, amount = entry.amount * amount, metadata = entry.metadata,
        })
    end
    return true, snapshot, nil, confirmation
end, { rateLimit = { max = 10, window = 5000 } })

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == resourceName then return end
    for id, owner in pairs(owners) do
        if owner == stoppedResource then
            areas[id], owners[id] = nil, nil
            TriggerClientEvent('qbcrafting:client:areaRemoved', -1, id)
        end
    end
end)

exports('RegisterCraftingArea', registerCraftingArea)
exports('RemoveCraftingArea', removeCraftingArea)
exports('GetCraftingArea', getCraftingArea)
exports('CanUseCraftingArea', function(source, id)
    local area = areas[id]
    if not area then return false, 'unknown crafting area' end
    if not playerInside(source, area) then return false, 'you are too far from this crafting area' end
    return checkAccess(source, area)
end)
exports('CraftAtArea', craftAtArea)

for key, definition in pairs(Config.areas or {}) do
    local configured = copy(definition)
    if type(key) == 'string' and configured.id == nil then configured.id = key end
    local registered, err = registerCraftingArea(configured, resourceName)
    if not registered then
        print(('^1[qbcrafting]^7 failed to register configured area %s: %s'):format(tostring(configured.id or key), tostring(err)))
    end
end
