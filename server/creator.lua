-- The creator: everything an admin can change from the in-game UI. Every callback is admin only.
-- Sections: payload, items, recipes, stations, command.

local function fail(message)
    return false, message
end

-- This is the one place the admin check lives.
local function adminCallback(name, handler)
    QB.callback.register(name, function(src, ...)
        if not isAdmin(src) then return fail('Admin permission required.') end
        if not DataLoaded then return fail('The crafting data is still loading. Try again in a moment.') end
        return handler(src, ...)
    end)
end

local function byLabel(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.id < b.id
end

-- ----------------------------------------------------------------------------
-- What the creator shows: every recipe and station, plus the items they mention
-- ----------------------------------------------------------------------------

local function payload()
    local shared, items = allItems(), {}
    local function track(name)
        if name and items[name] == nil then items[name] = itemEntry(shared, name) or false end
    end

    local recipes = {}
    for id, recipe in pairs(Recipes) do
        track(recipe.receive and recipe.receive.item)
        for _, entry in ipairs(recipe.give) do track(entry.item) end
        recipes[#recipes + 1] = {
            id = id, label = recipe.label, receive = recipe.receive, give = recipe.give,
            anim = recipe.anim, progress = recipe.progress,
            skill = recipe.skill, xp = recipe.xp, level = recipe.level,
        }
    end
    table.sort(recipes, byLabel)

    local stations = {}
    for id, station in pairs(Stations) do
        stations[#stations + 1] = {
            id = id, label = station.data.label,
            targetLabel = station.data.targetLabel, targetIcon = station.data.targetIcon,
            recipes = station.data.recipes, locations = station.locations,
        }
    end
    table.sort(stations, byLabel)

    local skills = GetSkills()
    return {
        recipes = recipes,
        stations = stations,
        items = items,
        skills = GetSkillList(),
        skillsAvailable = skills ~= nil,
    }
end

adminCallback('qbcrafting:creator:get', function()
    return payload()
end)

-- ----------------------------------------------------------------------------
-- Items. mode 'item' is the "what it makes" grid (an empty search lists items),
-- mode 'give' is the search for materials.
-- ----------------------------------------------------------------------------

adminCallback('qbcrafting:creator:items:search', function(_, query, mode, id)
    local recipe = validId(id) and Recipes[id]
    if not recipe then return fail('Unknown recipe.') end

    if mode == 'item' then
        local picked = recipe.receive and recipe.receive.item
        return searchItems(query, function(name) return name == picked end, Limits.pickerResults, true)
    end

    local inRecipe = {}
    for _, entry in ipairs(recipe.give) do inRecipe[entry.item] = true end
    return searchItems(query, function(name) return inRecipe[name] == true end, Limits.materialResults, false)
end)

-- ----------------------------------------------------------------------------
-- Recipes
-- ----------------------------------------------------------------------------

-- Runs change(copyOfRecipe), which returns the new recipe or nil and a message. Then saves and returns the page.
local function updateRecipe(id, change)
    local current = validId(id) and Recipes[id]
    if not current then return fail('Unknown recipe.') end

    local updated, err = change(copyTable(current))
    if not updated then return fail(err or 'Failed to save.') end

    local ok, saveErr = SaveRecipe(id, updated)
    if not ok then return fail(saveErr or 'Failed to save.') end
    return payload()
end

adminCallback('qbcrafting:creator:recipes:create', function(_, label)
    label = trim(label, 48)
    if not label then return fail('Enter a name for the recipe.') end

    local id = makeId(label, function(candidate) return Recipes[candidate] ~= nil end)
    local ok, err = SaveRecipe(id, newRecipe(label))
    if not ok then return fail(err or 'Failed to save.') end

    local result = payload()
    result.id = id
    return result
end)

adminCallback('qbcrafting:creator:recipes:details', function(_, id, input)
    return updateRecipe(id, function(recipe) return cleanRecipeDetails(input, recipe) end)
end)

adminCallback('qbcrafting:creator:recipes:item', function(_, id, item)
    local name = cleanName(item, 64, '^[%w_%-%.]+$')
    if not name or not itemExists(name) then return fail('That item does not exist.') end

    return updateRecipe(id, function(recipe)
        recipe.receive = { item = name, amount = recipe.receive and recipe.receive.amount or 1 }
        return recipe
    end)
end)

adminCallback('qbcrafting:creator:recipes:give', function(_, id, give)
    return updateRecipe(id, function(recipe)
        local clean, err = cleanGive(give, recipe.give)
        if not clean then return nil, err end
        recipe.give = clean
        return recipe
    end)
end)

adminCallback('qbcrafting:creator:recipes:delete', function(_, id)
    if not (validId(id) and Recipes[id]) then return fail('Unknown recipe.') end
    local ok, err = DeleteRecipe(id)
    if not ok then return fail(err or 'Failed to delete the recipe.') end
    return payload()
end)

-- ----------------------------------------------------------------------------
-- Stations
-- ----------------------------------------------------------------------------

-- Runs change(state) with a copy of the station as state = { data, locations }. change returns an
-- error message, or nothing when it worked. Then saves and returns the page.
local function updateStation(id, change)
    local station = validId(id) and Stations[id]
    if not station then return fail('Unknown station.') end

    local state = { data = copyTable(station.data), locations = copyTable(station.locations) }
    local err = change(state)
    if err then return fail(err) end

    local ok, saveErr = SaveStation(id, state.data, state.locations)
    if not ok then return fail(saveErr or 'Failed to save.') end
    return payload()
end

adminCallback('qbcrafting:creator:stations:create', function(_, label)
    label = trim(label, 48)
    if not label then return fail('Enter a name for the station.') end

    local id = makeId(label, function(candidate) return Stations[candidate] ~= nil end)
    local ok, err = SaveStation(id, newStation(label), {})
    if not ok then return fail(err or 'Failed to save.') end

    local result = payload()
    result.id = id
    return result
end)

adminCallback('qbcrafting:creator:stations:details', function(_, id, input)
    return updateStation(id, function(state)
        local data, err = cleanStationDetails(input, state.data)
        if not data then return err end
        state.data = data
    end)
end)

adminCallback('qbcrafting:creator:stations:recipes', function(_, id, list)
    return updateStation(id, function(state)
        local clean, err = cleanStationRecipes(list)
        if not clean then return err end
        state.data.recipes = clean
    end)
end)

adminCallback('qbcrafting:creator:stations:locations', function(_, id, list)
    return updateStation(id, function(state)
        local clean, err = cleanLocations(list)
        if not clean then return err end
        state.locations = clean
    end)
end)

adminCallback('qbcrafting:creator:stations:delete', function(_, id)
    if not (validId(id) and Stations[id]) then return fail('Unknown station.') end
    local ok, err = DeleteStation(id)
    if not ok then return fail(err or 'Failed to delete the station.') end
    return payload()
end)

-- ----------------------------------------------------------------------------

RegisterCommand(Config.Command, function(source)
    if not isAdmin(source) then
        QB.print.warn(('[qbcrafting] player %s was denied /%s: they do not have the "command" ace'):format(source, Config.Command))
        QB.notify.send(source, { title = 'Crafting Creator', message = 'Admin permission required.', type = 'error' })
        return
    end
    TriggerClientEvent('qbcrafting:creator:open', source)
end, false)
