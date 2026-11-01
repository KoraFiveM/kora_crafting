local patterns = {
    name = '^[%w_%-%.]+$',   -- items and objects
    anim = '^[%w_@%-%.]+$',
    gang = '^[%w_%-]+$',     -- gangs and jobs
    skill = '^[%w_%-%.]+$',
}

local disableAllowed = {}
for _, option in ipairs(ProgressDisableOptions) do disableAllowed[option.value] = true end

function allItems()
    local ok, items = pcall(function() return exports['qb-core']:GetShared('Items') end)
    if ok and type(items) == 'table' then return items end
    items = exports.kora_core:getShared('items')
    return type(items) == 'table' and items or {}
end

function itemExists(item)
    return type(allItems()[item]) == 'table'
end

function itemEntry(shared, name)
    local info = shared[name]
    if type(info) ~= 'table' then return nil end
    local image = type(info.image) == 'string' and info.image ~= '' and ('nui://kora_inventory/images/' .. info.image) or nil
    return { label = tostring(info.label or name), image = image }
end

local function byLabel(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.name < b.name
end

function searchItems(query, isAdded, limit, allowEmpty)
    local text = trim(query, 64)
    if not text and not allowEmpty then return false, 'Type part of an item name or label to search.' end
    local needle = text and text:lower()

    local shared, results = allItems(), {}
    for name in pairs(shared) do
        local entry = type(name) == 'string' and itemEntry(shared, name)
        if entry and (not needle or name:lower():find(needle, 1, true) or entry.label:lower():find(needle, 1, true)) then
            results[#results + 1] = { name = name, label = entry.label, image = entry.image, added = isAdded(name) == true }
        end
    end

    table.sort(results, byLabel)
    local total = #results
    while #results > limit do results[#results] = nil end
    return { results = results, total = total }
end

function validId(id)
    return type(id) == 'string' and #id <= 48 and id:match('^[%w_]+$') ~= nil
end

function makeId(label, isTaken)
    local base = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    base = base:sub(1, 36)
    if base == '' then base = 'new' end

    local id, n = base, 1
    while isTaken(id) do
        n = n + 1
        id = ('%s_%d'):format(base, n)
    end
    return id
end

function copyLabel(label, isTaken)
    local base, number = label:match('^(.-)%-(%d+)$')
    number = base and base ~= '' and (tonumber(number) + 1) or 2
    if not base or base == '' then base = label end

    while true do
        local suffix = '-' .. number
        local candidate = base:sub(1, 48 - #suffix) .. suffix
        if not isTaken(candidate) then return candidate end
        number = number + 1
    end
end

function newRecipe(label)
    return {
        label = label,
        receive = nil, -- { item, amount }: set with the item picker
        give = {},     -- { { item, amount, keep }, ... }
        anim = { dict = DefaultAnim.dict, clip = DefaultAnim.clip, flag = DefaultAnim.flag },
        progress = { time = DefaultProgress.time, label = DefaultProgress.label, disable = copyTable(DefaultProgress.disable) },
        tag = nil, -- optional search word for the creator; players never see it
        skill = nil, -- skill, xp and level are each optional: nil is a valid value for all three
        xp = nil,
        level = nil,
    }
end

function recipeComplete(recipe)
    return type(recipe.receive) == 'table' and recipe.receive.item ~= nil
end

local function cleanDisable(value)
    local disable = {}
    for key, on in pairs(type(value) == 'table' and value or {}) do
        local name = type(key) == 'string' and on == true and key or type(key) == 'number' and on
        if disableAllowed[name] then disable[name] = true end
    end
    return disable
end

function cleanGive(list, current)
    if type(list) ~= 'table' then return nil, 'Invalid item list.' end

    local already = {}
    for _, entry in ipairs(current or {}) do already[entry.item] = true end

    local clean, seen = {}, {}
    for _, entry in ipairs(list) do
        if #clean >= Limits.recipeItems then return nil, 'Too many items in one recipe.' end
        local item = type(entry) == 'table' and cleanName(entry.item, 64, patterns.name)
        if not item then return nil, 'Invalid item name.' end
        if seen[item] then return nil, ('%s is in the recipe twice.'):format(item) end
        seen[item] = true
        if not already[item] and not itemExists(item) then return nil, ('%s does not exist.'):format(item) end

        local amount = inRange(entry.amount, 1, Limits.recipeAmount, true)
        if not amount then
            return nil, ('The amount for %s must be between 1 and %d.'):format(item, Limits.recipeAmount)
        end
        clean[#clean + 1] = { item = item, amount = amount, keep = entry.keep == true or nil }
    end
    return clean
end

function cleanRecipeDetails(input, current)
    if type(input) ~= 'table' then return nil, 'Invalid data.' end
    local recipe = copyTable(current)

    local label = trim(input.label, 48)
    if not label then return nil, 'Enter a name for the recipe.' end
    recipe.label = label
    recipe.tag = trim(input.tag, 32) -- optional: empty clears it

    if recipe.receive then
        local amount = inRange(input.amount, 1, Limits.recipeAmount, true)
        if not amount then return nil, ('The amount made must be between 1 and %d.'):format(Limits.recipeAmount) end
        recipe.receive.amount = amount
    end

    local progress = type(input.progress) == 'table' and input.progress or {}
    local time = inRange(progress.time, 500, 300000, true)
    if not time then return nil, 'Progress time must be between 500 and 300000 ms.' end
    recipe.progress = {
        time = time,
        label = trim(progress.label, 64) or '',
        disable = cleanDisable(progress.disable),
    }

    local anim = type(input.anim) == 'table' and input.anim or {}
    local dict = cleanName(anim.dict, 64, patterns.anim)
    local clip = cleanName(anim.clip, 64, patterns.anim)
    if dict == false then return nil, 'Enter a valid animation dictionary.' end
    if clip == false then return nil, 'Enter a valid animation clip.' end
    if (dict == nil) ~= (clip == nil) then return nil, 'An animation needs both a dictionary and a clip.' end
    local flag = inRange(anim.flag, 0, 65535, true)
    if dict and not flag then return nil, 'Animation flag must be between 0 and 65535.' end
    recipe.anim = { dict = dict or '', clip = clip or '', flag = flag or DefaultAnim.flag }

    local skill = cleanName(input.skill, 48, patterns.skill)
    if skill == false then return nil, 'Invalid skill.' end
    if skill then
        local known = GetSkills()
        if known and known[skill] == nil then return nil, 'That skill does not exist.' end
    end

    local xp, level
    if input.xp ~= nil then
        xp = inRange(input.xp, 0, Limits.xp, true)
        if not xp then return nil, ('XP must be between 0 and %d.'):format(Limits.xp) end
    end
    if input.level ~= nil then
        level = inRange(input.level, 0, Limits.level, true)
        if not level then return nil, ('The level must be between 0 and %d.'):format(Limits.level) end
    end
    recipe.skill, recipe.xp, recipe.level = skill, xp, level

    return recipe
end

function readRecipe(id, raw)
    local stored = decodeJson(raw, {})
    local recipe = newRecipe(trim(stored.label, 48) or id)

    if type(stored.receive) == 'table' then
        local item = cleanName(stored.receive.item, 64, patterns.name)
        if item then
            recipe.receive = { item = item, amount = inRange(stored.receive.amount, 1, Limits.recipeAmount, true) or 1 }
        end
    end

    for _, entry in ipairs(type(stored.give) == 'table' and stored.give or {}) do
        local item = type(entry) == 'table' and cleanName(entry.item, 64, patterns.name)
        local amount = type(entry) == 'table' and inRange(entry.amount, 1, Limits.recipeAmount, true)
        if item and amount and #recipe.give < Limits.recipeItems then
            recipe.give[#recipe.give + 1] = { item = item, amount = amount, keep = entry.keep == true or nil }
        end
    end

    if type(stored.anim) == 'table' then
        recipe.anim = {
            dict = cleanName(stored.anim.dict, 64, patterns.anim) or '',
            clip = cleanName(stored.anim.clip, 64, patterns.anim) or '',
            flag = inRange(stored.anim.flag, 0, 65535, true) or DefaultAnim.flag,
        }
    end

    if type(stored.progress) == 'table' then
        recipe.progress = {
            time = inRange(stored.progress.time, 500, 300000, true) or DefaultProgress.time,
            label = trim(stored.progress.label, 64) or '',
            disable = cleanDisable(stored.progress.disable),
        }
    end

    recipe.tag = trim(stored.tag, 32)
    recipe.skill = cleanName(stored.skill, 48, patterns.skill) or nil
    recipe.xp = stored.xp ~= nil and inRange(stored.xp, 0, Limits.xp, true) or nil
    recipe.level = stored.level ~= nil and inRange(stored.level, 0, Limits.level, true) or nil
    return recipe
end

function newStation(label)
    return { label = label, targetLabel = 'Craft', targetIcon = 'fa-solid fa-hammer', recipes = {} }
end

function cleanStationDetails(input, current)
    if type(input) ~= 'table' then return nil, 'Invalid data.' end
    local data = copyTable(current)

    local label = trim(input.label, 48)
    if not label then return nil, 'Enter a name for the station.' end
    data.label = label
    data.targetLabel = trim(input.targetLabel, 48) or 'Craft'
    data.targetIcon = trim(input.targetIcon, 64) or 'fa-solid fa-hammer'
    return data
end

function cleanStationRecipes(list)
    if type(list) ~= 'table' then return nil, 'Invalid recipe list.' end
    local clean, seen = {}, {}
    for _, id in ipairs(list) do
        if #clean >= Limits.stationRecipes then return nil, 'Too many recipes on one station.' end
        if not (validId(id) and Recipes[id]) then return nil, 'Unknown recipe.' end
        if not seen[id] then
            seen[id] = true
            clean[#clean + 1] = id
        end
    end
    return clean
end

function cleanLocations(list)
    if type(list) ~= 'table' then return nil, 'Invalid locations.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= Limits.stationLocations then break end
        if type(entry) ~= 'table' then return nil, 'Invalid location.' end

        local coords = cleanVec(entry.coords)
        if not coords then return nil, 'Every location needs coordinates.' end
        if entry.coords.w ~= nil then
            coords.w = inRange(entry.coords.w, -720.0, 720.0)
            if not coords.w then return nil, 'Invalid heading.' end
        end

        local gang = cleanName(entry.gang, 32, patterns.gang)
        if gang == false then return nil, 'Gang may only contain letters, numbers, _ and -.' end
        local job = cleanName(entry.job, 32, patterns.gang)
        if job == false then return nil, 'Job may only contain letters, numbers, _ and -.' end
        local object = cleanName(entry.object, 64, patterns.name)
        if object == false then return nil, 'Object may only contain letters, numbers, _, - and .' end

        result[#result + 1] = { coords = coords, object = object, gang = gang, job = job }
    end
    return result
end

function readStation(id, row)
    local stored = decodeJson(row.data, {})
    local data = newStation(trim(stored.label, 48) or id)
    data.targetLabel = trim(stored.targetLabel, 48) or data.targetLabel
    data.targetIcon = trim(stored.targetIcon, 64) or data.targetIcon

    for _, recipeId in ipairs(type(stored.recipes) == 'table' and stored.recipes or {}) do
        if validId(recipeId) and #data.recipes < Limits.stationRecipes then data.recipes[#data.recipes + 1] = recipeId end
    end

    local locations = {}
    for _, entry in ipairs(decodeJson(row.locations, {})) do
        local coords = type(entry) == 'table' and cleanVec(entry.coords)
        if coords then
            if entry.coords.w ~= nil then coords.w = inRange(entry.coords.w, -720.0, 720.0) end
            locations[#locations + 1] = {
                coords = coords,
                object = cleanName(entry.object, 64, patterns.name) or nil,
                gang = cleanName(entry.gang, 32, patterns.gang) or nil,
                job = cleanName(entry.job, 32, patterns.gang) or nil,
            }
        end
    end
    return data, locations
end
