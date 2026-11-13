
local function fail(message)
    return false, message
end

local readOnly = {
    ['kora_crafting:creator:get'] = true,
    ['kora_crafting:creator:items:search'] = true,
}

local function adminCallback(name, handler)
    Kora.callback.register(name, function(src, ...)
        if not isAdmin(src) then return fail(Kora.lang('message.no_permission')) end
        if not DataLoaded then return fail(Kora.lang('message.data_loading')) end

        local id = ...
        local result, err = handler(src, ...)
        if result and not readOnly[name] then
            logAction(src, name, { id = id ~= nil and cutText(id, 100) or nil })
        end
        return result, err
    end)
end

local function byLabel(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.id < b.id
end

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
            tag = recipe.tag, skill = recipe.skill, xp = recipe.xp, level = recipe.level,
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

adminCallback('kora_crafting:creator:get', function()
    return payload()
end)

adminCallback('kora_crafting:creator:items:search', function(_, query, id)
    local recipe = validId(id) and Recipes[id]
    if not recipe then return fail(Kora.lang('error.unknown_recipe')) end

    local inRecipe = {}
    for _, entry in ipairs(recipe.give) do inRecipe[entry.item] = true end
    return searchItems(query, function(name) return inRecipe[name] == true end, Limits.materialResults, false)
end)

local function updateRecipe(id, change)
    local current = validId(id) and Recipes[id]
    if not current then return fail(Kora.lang('error.unknown_recipe')) end

    local updated, err = change(copyTable(current))
    if not updated then return fail(err or Kora.lang('message.failed_save')) end

    local ok, saveErr = SaveRecipe(id, updated)
    if not ok then return fail(saveErr or Kora.lang('message.failed_save')) end
    return payload()
end

adminCallback('kora_crafting:creator:recipes:create', function(_, label)
    label = trim(label, 48)
    if not label then return fail(Kora.lang('error.recipe_name')) end

    local id = makeId(label, function(candidate) return Recipes[candidate] ~= nil end)
    local ok, err = SaveRecipe(id, newRecipe(label))
    if not ok then return fail(err or Kora.lang('message.failed_save')) end

    local result = payload()
    result.id = id
    return result
end)

adminCallback('kora_crafting:creator:recipes:duplicate', function(_, id)
    local current = validId(id) and Recipes[id]
    if not current then return fail(Kora.lang('error.unknown_recipe')) end

    local copy = copyTable(current)
    copy.label = copyLabel(current.label, function(candidate)
        for _, recipe in pairs(Recipes) do
            if recipe.label == candidate then return true end
        end
        return false
    end)

    local newId = makeId(copy.label, function(candidate) return Recipes[candidate] ~= nil end)
    local ok, err = SaveRecipe(newId, copy)
    if not ok then return fail(err or Kora.lang('message.failed_save')) end

    local result = payload()
    result.id = newId
    return result
end)

adminCallback('kora_crafting:creator:recipes:details', function(_, id, input)
    return updateRecipe(id, function(recipe) return cleanRecipeDetails(input, recipe) end)
end)

adminCallback('kora_crafting:creator:recipes:item', function(_, id, item)
    local name = cleanName(item, 64, '^[%w_%-%.]+$')
    if not name or not itemExists(name) then return fail(Kora.lang('error.item_missing')) end

    return updateRecipe(id, function(recipe)
        recipe.receive = { item = name, amount = recipe.receive and recipe.receive.amount or 1 }
        return recipe
    end)
end)

adminCallback('kora_crafting:creator:recipes:give', function(_, id, give)
    return updateRecipe(id, function(recipe)
        local clean, err = cleanGive(give, recipe.give)
        if not clean then return nil, err end
        recipe.give = clean
        return recipe
    end)
end)

adminCallback('kora_crafting:creator:recipes:delete', function(_, id)
    if not (validId(id) and Recipes[id]) then return fail(Kora.lang('error.unknown_recipe')) end
    local ok, err = DeleteRecipe(id)
    if not ok then return fail(err or Kora.lang('error.failed_delete_recipe')) end
    return payload()
end)

local function updateStation(id, change)
    local station = validId(id) and Stations[id]
    if not station then return fail(Kora.lang('error.unknown_station')) end

    local state = { data = copyTable(station.data), locations = copyTable(station.locations) }
    local err = change(state)
    if err then return fail(err) end

    local ok, saveErr = SaveStation(id, state.data, state.locations)
    if not ok then return fail(saveErr or Kora.lang('message.failed_save')) end
    return payload()
end

adminCallback('kora_crafting:creator:stations:create', function(_, label)
    label = trim(label, 48)
    if not label then return fail(Kora.lang('error.station_name')) end

    local id = makeId(label, function(candidate) return Stations[candidate] ~= nil end)
    local ok, err = SaveStation(id, newStation(label), {})
    if not ok then return fail(err or Kora.lang('message.failed_save')) end

    local result = payload()
    result.id = id
    return result
end)

adminCallback('kora_crafting:creator:stations:duplicate', function(_, id)
    local current = validId(id) and Stations[id]
    if not current then return fail(Kora.lang('error.unknown_station')) end

    local data = copyTable(current.data)
    data.label = copyLabel(current.data.label, function(candidate)
        for _, station in pairs(Stations) do
            if station.data.label == candidate then return true end
        end
        return false
    end)

    local newId = makeId(data.label, function(candidate) return Stations[candidate] ~= nil end)
    local ok, err = SaveStation(newId, data, {})
    if not ok then return fail(err or Kora.lang('message.failed_save')) end

    local result = payload()
    result.id = newId
    return result
end)

adminCallback('kora_crafting:creator:stations:details', function(_, id, input)
    return updateStation(id, function(state)
        local data, err = cleanStationDetails(input, state.data)
        if not data then return err end
        state.data = data
    end)
end)

adminCallback('kora_crafting:creator:stations:recipes', function(_, id, list)
    return updateStation(id, function(state)
        local clean, err = cleanStationRecipes(list)
        if not clean then return err end
        state.data.recipes = clean
    end)
end)

adminCallback('kora_crafting:creator:stations:locations', function(_, id, list)
    return updateStation(id, function(state)
        local clean, err = cleanLocations(list)
        if not clean then return err end
        state.locations = clean
    end)
end)

adminCallback('kora_crafting:creator:stations:delete', function(_, id)
    if not (validId(id) and Stations[id]) then return fail(Kora.lang('error.unknown_station')) end
    local ok, err = DeleteStation(id)
    if not ok then return fail(err or Kora.lang('error.failed_delete_station')) end
    return payload()
end)

RegisterCommand(Config.Command, function(source)
    if not isAdmin(source) then
        Kora.print.warn(('[kora_crafting] player %s was denied /%s: they do not have the "command" ace'):format(source, Config.Command))
        Kora.notify.send(source, { title = Kora.lang('creator_title'), message = Kora.lang('message.no_permission'), type = 'error' })
        return
    end
    TriggerClientEvent('kora_crafting:creator:open', source)
end, false)
