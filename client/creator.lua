
local APP_ID = 'qbcrafting:creator'

local data = { recipes = {}, stations = {}, items = {}, skills = {}, skillsAvailable = false }
local selectedRecipe, selectedStation = nil, nil -- ids
local currentView = 'recipes'
local stationRecipeQuery = '' -- the search box above the recipes you can add to a station
local pendingTool = nil
local revision = 0

local itemSearch = { query = nil, results = {}, total = 0 } -- one search; each card can be the result or a material

local function notice(message, tone)
    return { tone = tone or 'success', message = message }
end

local function text(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function optionalText(value)
    local result = text(value)
    return result ~= '' and result or nil
end

local function toast(message)
    Kora.notify.send({ title = 'Crafting Creator', message = message, type = 'error' })
end

local function confirmed(title, message)
    local answer = Kora.nui.openAlert({ title = title, message = message, confirmLabel = 'Delete' })
    return answer and answer.confirmed == true
end

local function askName(title, label)
    local result = Kora.nui.openInputDialog({
        { id = 'name', label = label, type = 'text', required = true },
    }, title, 'You can change it later.')
    if not result or result.cancelled then return nil end
    return optionalText(result.values and result.values.name)
end

local function appended(list, entry)
    local copy = {}
    for _, value in ipairs(list or {}) do copy[#copy + 1] = value end
    copy[#copy + 1] = entry
    return copy
end

local function removedAt(list, index)
    local kept = {}
    for position, value in ipairs(list or {}) do
        if position ~= index then kept[#kept + 1] = value end
    end
    return kept
end

local function coordsLabel(c)
    return ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)
end

local function disableList(map)
    local list = {}
    for key, on in pairs(map or {}) do
        if on == true then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

local function recipeEntry(id)
    for _, recipe in ipairs(data.recipes) do
        if recipe.id == id then return recipe end
    end
end

local function stationEntry(id)
    for _, station in ipairs(data.stations) do
        if station.id == id then return station end
    end
end

local function itemLabel(name)
    local info = data.items[name]
    return info and info.label or name
end

local function itemImage(name)
    local info = data.items[name]
    return info and info.image or nil
end

local function blockId(name, id)
    return ('%s:%s:%d'):format(name, id, revision)
end


local function makesText(recipe)
    if not recipe.receive then return 'Makes nothing yet' end
    return ('Makes %dx %s'):format(recipe.receive.amount, itemLabel(recipe.receive.item))
end

local function needsText(recipe)
    local parts = {}
    for _, entry in ipairs(recipe.give) do
        parts[#parts + 1] = ('%dx %s'):format(entry.amount, itemLabel(entry.item))
    end
    return #parts > 0 and table.concat(parts, ', ') or 'Nothing'
end

local function skillLabel(name)
    for _, skill in ipairs(data.skills) do
        if skill.value == name then return skill.label end
    end
    return name
end

local function tagMetadata(recipe, metadata)
    metadata = metadata or {}
    if recipe.tag then metadata[#metadata + 1] = { label = 'Tag', value = recipe.tag } end
    return metadata
end

local function recipeMatches(recipe, query)
    if query == '' then return true end
    local haystack = table.concat({
        recipe.label or '',
        recipe.tag or '',
        recipe.receive and recipe.receive.item or '',
        recipe.receive and itemLabel(recipe.receive.item) or '',
    }, ' '):lower()
    for word in query:lower():gmatch('%S+') do
        if not haystack:find(word, 1, true) then return false end
    end
    return true
end

local function recipesView()
    local items = {}
    for _, recipe in ipairs(data.recipes) do
        local metadata = { { label = 'Needs', value = needsText(recipe) } }
        if recipe.skill then
            metadata[#metadata + 1] = {
                label = 'Skill',
                value = (recipe.level or 0) > 0 and ('%s · level %d'):format(skillLabel(recipe.skill), recipe.level) or skillLabel(recipe.skill),
            }
        end
        if not recipe.receive then metadata[#metadata + 1] = { label = 'Status', value = 'Not finished: pick the item it makes' } end
        tagMetadata(recipe, metadata)

        items[#items + 1] = {
            id = recipe.id,
            label = recipe.label,
            description = makesText(recipe),
            image = recipe.receive and itemImage(recipe.receive.item) or nil,
            metadata = metadata,
            action = 'recipe:select:' .. recipe.id,
        }
    end

    return {
        id = 'recipes', label = 'Recipes', icon = 'FlaskConical',
        content = {
            title = 'Recipes',
            description = 'Pick a recipe to change it, or create a new one. Put recipes on a station on the Stations page.',
            blocks = {
                {
                    type = 'actions',
                    actions = { { id = 'recipe:new', label = 'Create new recipe', icon = 'Plus', variant = 'primary' } },
                },
                {
                    type = 'list', id = 'recipe-list', layout = 'cards', columns = 3,
                    title = ('Recipes (%d)'):format(#items), items = items,
                    empty = 'No recipes yet. Create one to get started.',
                },
            },
        },
    }
end

local function resultCards(results, recipe)
    local makesItem = recipe.receive and recipe.receive.item
    local cards = {}
    for _, result in ipairs(results) do
        local isResult = result.name == makesItem
        local metadata = {}
        if isResult then metadata[#metadata + 1] = { label = 'Makes', value = 'This is the result' } end
        if result.added then metadata[#metadata + 1] = { label = 'Needs', value = 'In the recipe' } end

        local actions = {}
        if not isResult then
            actions[#actions + 1] = { id = 'recipe:pick:' .. result.name, label = 'Set as result', icon = 'Check', variant = 'primary' }
        end
        if not result.added then
            actions[#actions + 1] = { id = 'recipe:add:' .. result.name, label = 'Add to recipe', icon = 'Plus', variant = 'primary' }
        end

        cards[#cards + 1] = {
            id = result.name,
            label = result.label,
            description = result.name,
            image = result.image,
            metadata = #metadata > 0 and metadata or nil,
            actions = actions,
        }
        if #cards == 15 then break end
    end
    return cards
end

local function detailsForm(recipe)
    local progress, anim = recipe.progress or {}, recipe.anim or {}

    local fields = {
        { id = 'label', label = 'Recipe name', type = 'text', required = true, default = recipe.label },
        { id = 'tag', label = 'Tag', type = 'text', default = recipe.tag or '',
            description = 'Optional. Players never see it. Search for it when adding recipes to a station.' },
    }
    if recipe.receive then
        fields[#fields + 1] = { id = 'amount', label = 'Amount made', type = 'number', min = 1, max = 1000, default = recipe.receive.amount }
    end

    fields[#fields + 1] = { id = 'progressLabel', label = 'Progress text', type = 'text', default = progress.label or '',
        description = 'Shown on the progress bar while crafting.' }
    fields[#fields + 1] = { id = 'progressTime', label = 'Progress time (ms)', type = 'number', min = 500, max = 300000, default = progress.time or 5000 }
    fields[#fields + 1] = { id = 'animDict', label = 'Animation dictionary', type = 'text', default = anim.dict or '',
        description = 'e.g. mp_arresting. Leave the dictionary and the clip empty for no animation.' }
    fields[#fields + 1] = { id = 'animClip', label = 'Animation clip', type = 'text', default = anim.clip or '',
        description = 'The clip inside that dictionary, e.g. a_uncuff.' }
    fields[#fields + 1] = { id = 'animFlag', label = 'Animation flag', type = 'number', min = 0, max = 65535, default = anim.flag or 49,
        description = 'GTA animation flags. 49 keeps the upper body animating while allowing movement.' }
    fields[#fields + 1] = { id = 'disable', label = 'Disable while crafting', type = 'multiselect', options = ProgressDisableOptions,
        default = disableList(progress.disable), description = 'Controls blocked while the progress bar runs.' }

    if #data.skills > 0 or recipe.skill then
        local options, known = { { value = 'none', label = 'No skill' } }, {}
        for _, skill in ipairs(data.skills) do
            options[#options + 1] = skill
            known[skill.value] = true
        end
        if recipe.skill and not known[recipe.skill] then options[#options + 1] = { value = recipe.skill, label = recipe.skill } end

        fields[#fields + 1] = { id = 'skill', label = 'Skill', type = 'select', options = options, default = recipe.skill or 'none',
            description = 'Optional. The skill a player needs a level in to craft this, and that the xp goes to.' }
    else
        fields[#fields + 1] = { id = 'skill', label = 'Skill', type = 'text', default = '',
            description = 'Optional. The skills resource could not be read, so type the skill name. Leave empty for none.' }
    end
    fields[#fields + 1] = { id = 'level', label = 'Level required', type = 'number', min = 0, max = 1000, default = recipe.level,
        description = 'Optional. Leave empty or 0 for no level. Only used when a skill is set.' }
    fields[#fields + 1] = { id = 'xp', label = 'XP given', type = 'number', min = 0, max = 100000, default = recipe.xp,
        description = 'Optional. The xp a player gets in that skill each time they craft this. Leave empty for none.' }

    return {
        type = 'form', id = blockId('recipe-details', recipe.id), title = 'Details',
        fields = fields,
        action = { id = 'recipe:details', label = 'Save' },
    }
end

local function recipeView()
    local recipe = recipeEntry(selectedRecipe)
    if not recipe then
        return {
            id = 'recipe', label = 'Recipe', icon = 'FlaskConical',
            content = { title = 'Recipe', blocks = { { type = 'empty', title = 'Pick a recipe first.' } } },
        }
    end

    local blocks = { detailsForm(recipe) }
    local makes = recipe.receive
    blocks[#blocks + 1] = {
        type = 'list', id = 'recipe-makes', layout = 'cards', columns = 3, title = 'What it makes',
        items = makes and { {
            id = makes.item, label = itemLabel(makes.item), description = makes.item, image = itemImage(makes.item),
            metadata = { { label = 'Amount', value = ('%dx'):format(makes.amount) } },
        } } or {},
        empty = 'Nothing chosen yet. Search below and press Set as result.',
    }

    local found = resultCards(itemSearch.results, recipe)
    blocks[#blocks + 1] = {
        type = 'form', id = 'recipe-search', title = 'Find items',
        fields = { { id = 'query', label = 'Search all items', type = 'text', default = itemSearch.query or '',
            description = 'Part of an item name or label. Press Set as result for what it makes, or Add to recipe for what it needs.' } },
        action = { id = 'recipe:search', label = 'Search' },
    }
    if itemSearch.query then
        local extra = itemSearch.total > #found and (' of ' .. itemSearch.total) or ''
        blocks[#blocks + 1] = {
            type = 'list', id = 'recipe-results', layout = 'cards', columns = 3,
            title = ('Results for "%s" (%d%s)'):format(itemSearch.query, #found, extra),
            items = found, empty = 'No items match that search.',
        }
    end

    local required = {}
    for _, entry in ipairs(recipe.give) do
        local info = data.items[entry.item]
        required[#required + 1] = {
            id = entry.item,
            label = itemLabel(entry.item),
            description = info and entry.item or (entry.item .. ' · not in the shared items'),
            image = itemImage(entry.item),
            metadata = {
                { label = 'Amount', value = ('%dx'):format(entry.amount) },
                entry.keep and { label = 'Used up', value = 'No, kept' } or nil,
            },
            actions = {
                { id = 'recipe:edit:' .. entry.item, label = 'Edit', icon = 'Pencil', variant = 'primary' },
                { id = 'recipe:remove:' .. entry.item, label = 'Remove', icon = 'Trash2', variant = 'destructive' },
            },
        }
    end
    blocks[#blocks + 1] = {
        type = 'list', id = 'recipe-required', layout = 'cards', columns = 3,
        title = ('Required items (%d)'):format(#required),
        items = required, empty = 'Nothing is required yet. Search above to add an item.',
    }

    blocks[#blocks + 1] = {
        type = 'actions',
        actions = { { id = 'recipe:duplicate', label = 'Duplicate recipe', icon = 'Copy', variant = 'primary' } },
    }
    blocks[#blocks + 1] = {
        type = 'actions', title = 'Danger zone',
        actions = { { id = 'recipe:delete', label = 'Delete recipe', variant = 'destructive' } },
    }

    local description = makesText(recipe) .. '.'
    return {
        id = 'recipe', label = recipe.label, icon = 'FlaskConical',
        content = { title = recipe.label, description = description, blocks = blocks },
    }
end

local function stationsView()
    local items = {}
    for _, station in ipairs(data.stations) do
        items[#items + 1] = {
            id = station.id,
            label = station.label,
            icon = 'Hammer',
            description = ('%d recipe(s) · %d location(s)'):format(#station.recipes, #station.locations),
            action = 'station:select:' .. station.id,
        }
    end

    return {
        id = 'stations', label = 'Stations', icon = 'Hammer',
        content = {
            title = 'Crafting stations',
            description = 'A station is where players craft. Pick one to set its recipes and its locations.',
            blocks = {
                {
                    type = 'actions',
                    actions = { { id = 'station:new', label = 'Create new station', icon = 'Plus', variant = 'primary' } },
                },
                {
                    type = 'list', id = 'station-list', layout = 'cards', columns = 3,
                    title = ('Stations (%d)'):format(#items), items = items,
                    empty = 'No stations yet. Create one to get started.',
                },
            },
        },
    }
end

local function stationView()
    local station = stationEntry(selectedStation)
    if not station then
        return {
            id = 'station', label = 'Station', icon = 'Hammer',
            content = { title = 'Station', blocks = { { type = 'empty', title = 'Pick a station first.' } } },
        }
    end

    local onStation, taken = {}, {}
    for _, id in ipairs(station.recipes) do
        local recipe = recipeEntry(id)
        if recipe then
            taken[id] = true
            onStation[#onStation + 1] = {
                id = id, label = recipe.label, description = makesText(recipe),
                image = recipe.receive and itemImage(recipe.receive.item) or nil,
                metadata = #tagMetadata(recipe) > 0 and tagMetadata(recipe) or nil,
                actions = { { id = 'station:remove:' .. id, label = 'Remove', icon = 'Trash2', variant = 'destructive' } },
            }
        end
    end

    local available = {}
    for _, recipe in ipairs(data.recipes) do
        if not taken[recipe.id] and recipeMatches(recipe, stationRecipeQuery) then
            local metadata = tagMetadata(recipe)
            if not recipe.receive then metadata[#metadata + 1] = { label = 'Status', value = 'Not finished: players will not see it' } end
            available[#available + 1] = {
                id = recipe.id, label = recipe.label, description = makesText(recipe),
                image = recipe.receive and itemImage(recipe.receive.item) or nil,
                metadata = #metadata > 0 and metadata or nil,
                actions = { { id = 'station:add:' .. recipe.id, label = 'Add', icon = 'Plus', variant = 'primary' } },
            }
        end
    end

    local locations = {}
    for index, location in ipairs(station.locations) do
        local tags = {}
        if location.gang then tags[#tags + 1] = 'gang ' .. location.gang end
        if location.job then tags[#tags + 1] = 'job ' .. location.job end
        if location.object then tags[#tags + 1] = location.object end
        locations[#locations + 1] = {
            id = tostring(index),
            label = ('Location %d%s'):format(index, #tags > 0 and (' · ' .. table.concat(tags, ' · ')) or ''),
            icon = 'MapPin',
            description = coordsLabel(location.coords),
            actions = { { id = 'station:dropLoc:' .. index, label = 'Delete', icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'station', label = station.label, icon = 'Hammer',
        content = {
            title = station.label,
            description = 'The target text, the recipes players can craft here, and where the station is.',
            blocks = {
                {
                    type = 'form', id = blockId('station-details', station.id), title = 'Settings',
                    fields = {
                        { id = 'label', label = 'Station name', type = 'text', required = true, default = station.label },
                        { id = 'targetLabel', label = 'Target label', type = 'text', default = station.targetLabel or 'Craft' },
                        { id = 'targetIcon', label = 'Target icon', type = 'text', default = station.targetIcon or 'fa-solid fa-hammer' },
                    },
                    action = { id = 'station:details', label = 'Save' },
                },
                {
                    type = 'list', id = 'station-recipes', layout = 'cards', columns = 3,
                    title = ('Recipes on this station (%d)'):format(#onStation), items = onStation,
                    empty = 'No recipes yet. Add some below.',
                },
                {
                    type = 'form', id = 'station-recipe-search', title = 'Find a recipe to add',
                    fields = { { id = 'recipeQuery', label = 'Search recipes', type = 'text', default = stationRecipeQuery,
                        description = 'Matches the recipe name, its tag, or the item it makes. Several words must all match. Empty shows every recipe.' } },
                    action = { id = 'station:search', label = 'Search' },
                },
                {
                    type = 'list', id = 'station-available', layout = 'cards', columns = 3,
                    title = ('Recipes you can add (%d)'):format(#available), items = available,
                    empty = stationRecipeQuery ~= '' and 'No recipes match that search.' or 'Every recipe is on this station already.',
                },
                {
                    type = 'form', id = blockId('station-place', station.id), title = 'Place locations',
                    fields = {
                        { id = 'gang', label = 'Gang', type = 'text', default = '',
                            description = 'Only members of this gang can use the location.' },
                        { id = 'job', label = 'Job', type = 'text', default = '',
                            description = 'Only people with this job can use the location. With a gang and a job, either one is enough. Empty for both = everyone.' },
                        { id = 'object', label = 'Object', type = 'text', default = '',
                            description = 'Optional prop model, e.g. prop_toolchest_01. When set, the prop is placed where you aim and players use the prop. Leave empty for a plain zone.' },
                    },
                    action = { id = 'station:place', label = 'Aim and place locations' },
                },
                {
                    type = 'list', id = 'station-locations', layout = 'cards', columns = 3,
                    title = ('Locations (%d)'):format(#locations), items = locations, empty = 'No locations yet.',
                },
                {
                    type = 'actions',
                    actions = { { id = 'station:duplicate', label = 'Duplicate station (settings and recipes only)', icon = 'Copy', variant = 'primary' } },
                },
                {
                    type = 'actions', title = 'Danger zone',
                    actions = { { id = 'station:delete', label = 'Delete station', variant = 'destructive' } },
                },
            },
        },
    }
end

local function buildNavigation()
    local navigation = { recipesView() }
    if selectedRecipe and recipeEntry(selectedRecipe) then navigation[#navigation + 1] = recipeView() end
    navigation[#navigation + 1] = stationsView()
    if selectedStation and stationEntry(selectedStation) then navigation[#navigation + 1] = stationView() end
    return navigation
end

local function refresh(message)
    local navigation = buildNavigation()
    Kora.nui.updateApp(APP_ID, { navigation = navigation })
    return { update = { navigation = navigation }, notice = message }
end

local function fail(message)
    return refresh(notice(message, 'destructive'))
end

local function setData(result)
    data.recipes = result.recipes or {}
    data.stations = result.stations or {}
    data.items = result.items or {}
    data.skills = result.skills or {}
    data.skillsAvailable = result.skillsAvailable == true
    if selectedRecipe and not recipeEntry(selectedRecipe) then selectedRecipe = nil end
    if selectedStation and not stationEntry(selectedStation) then selectedStation = nil end
end

local function clearItemSearch()
    itemSearch.query, itemSearch.results, itemSearch.total = nil, {}, 0
end

local function change(callback, ...)
    local result, err = Kora.callback.trigger(callback, ...)
    if not result then return nil, err end
    setData(result)
    revision = revision + 1
    return result
end

local function openRecipe(id, message)
    selectedRecipe = id
    clearItemSearch()
    revision = revision + 1
    currentView = 'recipe'
    return refresh(message)
end

local function askAmount(label, title, current)
    local result = Kora.nui.openInputDialog({
        { id = 'amount', label = 'Amount needed', type = 'number', min = 1, max = 1000, default = current and current.amount or 1, required = true },
        {
            id = 'keep', label = 'Used up when crafting?', type = 'select',
            default = current and current.keep and 'keep' or 'use',
            options = { { value = 'use', label = 'Yes, used up' }, { value = 'keep', label = 'No, the player keeps it' } },
        },
    }, title, label)
    if not result or result.cancelled then return nil end

    local amount = tonumber(result.values and result.values.amount)
    if not amount then return nil end
    return { amount = math.floor(amount), keep = result.values.keep == 'keep' or nil }
end

local function giveCopy(recipe)
    local copy = {}
    for _, entry in ipairs(recipe.give) do
        copy[#copy + 1] = { item = entry.item, amount = entry.amount, keep = entry.keep }
    end
    return copy
end

local function saveGive(recipe, give, message)
    local result, err = change('qbcrafting:creator:recipes:give', recipe.id, give)
    if not result then return fail(err or 'Failed to save.') end

    local updated = recipeEntry(recipe.id)
    local inRecipe = {}
    for _, entry in ipairs(updated and updated.give or {}) do inRecipe[entry.item] = true end
    for _, found in ipairs(itemSearch.results) do found.added = inRecipe[found.name] == true end
    return refresh(notice(message))
end

local function detailsInput(values, recipe)
    local disable = {}
    for _, key in ipairs(type(values.disable) == 'table' and values.disable or {}) do disable[#disable + 1] = key end

    local skill = optionalText(values.skill)
    if skill == 'none' then skill = nil end

    return {
        label = text(values.label),
        tag = text(values.tag),
        amount = tonumber(values.amount),
        progress = { label = text(values.progressLabel), time = tonumber(values.progressTime), disable = disable },
        anim = { dict = text(values.animDict), clip = text(values.animClip), flag = tonumber(values.animFlag) },
        skill = skill,
        xp = tonumber(values.xp),
        level = tonumber(values.level),
    }
end

local function recipeAction(actionId, values)
    if actionId == 'recipe:new' then
        local name = askName('New recipe', 'Recipe name')
        if not name then return refresh() end

        local result, err = change('qbcrafting:creator:recipes:create', name)
        if not result then return fail(err or 'Failed to create the recipe.') end
        return openRecipe(result.id, notice('Recipe created. Pick the item it makes and add what it needs.'))
    end

    local selectId = actionId:match('^recipe:select:(.+)$')
    if selectId then
        if not recipeEntry(selectId) then return fail('Unknown recipe.') end
        return openRecipe(selectId)
    end

    local recipe = recipeEntry(selectedRecipe)
    if not recipe then return fail('Pick a recipe first.') end

    if actionId == 'recipe:details' then
        local input = detailsInput(values, recipe)
        if input.anim.dict ~= '' and not DoesAnimDictExist(input.anim.dict) then return fail('Unknown animation dictionary.') end

        local result, err = change('qbcrafting:creator:recipes:details', recipe.id, input)
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice('Saved.'))
    end

    local pickName = actionId:match('^recipe:pick:(.+)$')
    if pickName then
        local result, err = change('qbcrafting:creator:recipes:item', recipe.id, pickName)
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice(('It now makes %s.'):format(itemLabel(pickName))))
    end

    if actionId == 'recipe:duplicate' then
        local result, err = change('qbcrafting:creator:recipes:duplicate', recipe.id)
        if not result then return fail(err or 'Failed to duplicate the recipe.') end
        return openRecipe(result.id, notice('Recipe duplicated. You are now editing the copy.'))
    end

    if actionId == 'recipe:delete' then
        local message = ('This removes %s, and takes it off every station that has it.'):format(recipe.label)
        if not confirmed('Delete recipe?', message) then return refresh() end

        local result, err = change('qbcrafting:creator:recipes:delete', recipe.id)
        if not result then return fail(err or 'Failed to delete the recipe.') end
        selectedRecipe, currentView = nil, 'recipes'
        return refresh(notice('Recipe deleted.'))
    end

    if actionId == 'recipe:search' then
        local query = text(values.query)
        if query == '' then
            clearItemSearch()
            return refresh()
        end

        local result, err = Kora.callback.trigger('qbcrafting:creator:items:search', query, recipe.id)
        if not result then return fail(err or 'The search failed.') end
        itemSearch.query, itemSearch.results = query, result.results or {}
        itemSearch.total = result.total or #itemSearch.results
        return refresh()
    end

    local addName = actionId:match('^recipe:add:(.+)$')
    if addName then
        local found
        for _, result in ipairs(itemSearch.results) do
            if result.name == addName then found = result break end
        end
        if not found then return fail('Search for that item again first.') end

        local picked = askAmount(found.label, 'Add to recipe')
        if not picked then return refresh() end

        local give = giveCopy(recipe)
        give[#give + 1] = { item = addName, amount = picked.amount, keep = picked.keep }
        return saveGive(recipe, give, ('%dx %s added.'):format(picked.amount, found.label))
    end

    local editName = actionId:match('^recipe:edit:(.+)$')
    if editName then
        local give = giveCopy(recipe)
        local entry
        for _, candidate in ipairs(give) do
            if candidate.item == editName then entry = candidate break end
        end
        if not entry then return refresh() end

        local picked = askAmount(itemLabel(editName), 'Edit item', entry)
        if not picked then return refresh() end

        entry.amount, entry.keep = picked.amount, picked.keep
        return saveGive(recipe, give, ('%s now needs %dx.'):format(itemLabel(editName), picked.amount))
    end

    local removeName = actionId:match('^recipe:remove:(.+)$')
    if removeName then
        local give = {}
        for _, entry in ipairs(giveCopy(recipe)) do
            if entry.item ~= removeName then give[#give + 1] = entry end
        end
        return saveGive(recipe, give, ('%s removed.'):format(itemLabel(removeName)))
    end

    return refresh()
end

local function openStation(id, message)
    selectedStation = id
    stationRecipeQuery = ''
    revision = revision + 1
    currentView = 'station'
    return refresh(message)
end

local function stationRecipeIds(station, without, with)
    local ids = {}
    for _, id in ipairs(station.recipes) do
        if id ~= without then ids[#ids + 1] = id end
    end
    if with then ids[#ids + 1] = with end
    return ids
end

local function stationAction(actionId, values)
    if actionId == 'station:new' then
        local name = askName('New station', 'Station name')
        if not name then return refresh() end

        local result, err = change('qbcrafting:creator:stations:create', name)
        if not result then return fail(err or 'Failed to create the station.') end
        return openStation(result.id, notice('Station created. Add recipes and place its locations.'))
    end

    local selectId = actionId:match('^station:select:(.+)$')
    if selectId then
        if not stationEntry(selectId) then return fail('Unknown station.') end
        return openStation(selectId)
    end

    local station = stationEntry(selectedStation)
    if not station then return fail('Pick a station first.') end

    if actionId == 'station:details' then
        local result, err = change('qbcrafting:creator:stations:details', station.id, {
            label = text(values.label),
            targetLabel = text(values.targetLabel),
            targetIcon = text(values.targetIcon),
        })
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice('Saved.'))
    end

    if actionId == 'station:search' then
        stationRecipeQuery = text(values.recipeQuery)
        return refresh()
    end

    local addId = actionId:match('^station:add:(.+)$')
    if addId then
        local result, err = change('qbcrafting:creator:stations:recipes', station.id, stationRecipeIds(station, nil, addId))
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice('Recipe added.'))
    end

    local removeId = actionId:match('^station:remove:(.+)$')
    if removeId then
        local result, err = change('qbcrafting:creator:stations:recipes', station.id, stationRecipeIds(station, removeId))
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice('Recipe removed.'))
    end

    if actionId == 'station:place' then
        local object = optionalText(values.object)
        if object and not IsModelInCdimage(GetHashKey(object)) then return fail('Unknown object model.') end
        pendingTool = { kind = 'point', object = object, gang = optionalText(values.gang), job = optionalText(values.job) }
        currentView = 'station'
        return { close = true }
    end

    local dropIndex = actionId:match('^station:dropLoc:(%d+)$')
    if dropIndex then
        local result, err = change('qbcrafting:creator:stations:locations', station.id, removedAt(station.locations, tonumber(dropIndex)))
        if not result then return fail(err or 'Failed to save.') end
        return refresh(notice('Deleted.'))
    end

    if actionId == 'station:duplicate' then
        local result, err = change('qbcrafting:creator:stations:duplicate', station.id)
        if not result then return fail(err or 'Failed to duplicate the station.') end
        return openStation(result.id, notice('Station duplicated without locations. You are now editing the copy.'))
    end

    if actionId == 'station:delete' then
        local message = ('This removes %s and all of its locations.'):format(station.label)
        if not confirmed('Delete station?', message) then return refresh() end

        local result, err = change('qbcrafting:creator:stations:delete', station.id)
        if not result then return fail(err or 'Failed to delete the station.') end
        selectedStation, currentView = nil, 'stations'
        return refresh(notice('Station deleted.'))
    end

    return refresh()
end


local function onAction(actionId, context)
    local values = context and context.value or {}
    if actionId:match('^recipe:') then return recipeAction(actionId, values) end
    if actionId:match('^station:') then return stationAction(actionId, values) end
    return refresh()
end

Kora.nui.registerApp({
    id = APP_ID,
    title = 'Crafting Creator',
    icon = 'Hammer',
    layout = 'standard',
    width = 1200,
    height = 800,
    defaultView = 'recipes',
    navigation = { { id = 'recipes', label = 'Recipes', icon = 'FlaskConical', content = { title = 'Recipes', blocks = {} } } },
    onAction = onAction,
})

local function placeUntilCancelled(tool)
    while true do
        local aimed = Kora.raycast.getCoords(tool.object and { type = 'object', object = tool.object } or {})
        local c = aimed and aimed.coords
        if not c then return end

        local station = stationEntry(selectedStation)
        if not station then return end

        local place = {
            coords = { x = c.x, y = c.y, z = c.z, w = c.w or aimed.heading },
            object = tool.object, gang = tool.gang, job = tool.job,
        }
        local result, err = change('qbcrafting:creator:stations:locations', station.id, appended(station.locations, place))
        if not result then
            toast(err or 'Failed to save the location.')
            return
        end
    end
end

local function open()
    local result, err = Kora.callback.trigger('qbcrafting:creator:get')
    if not result then
        toast(err or 'Admin permission required.')
        return
    end

    setData(result)
    clearItemSearch()

    while true do
        Kora.nui.updateApp(APP_ID, { navigation = buildNavigation() })
        Kora.nui.openApp(APP_ID, { viewId = currentView })
        if not pendingTool then break end

        local tool = pendingTool
        pendingTool = nil
        placeUntilCancelled(tool)
    end
end

RegisterNetEvent('qbcrafting:creator:open', function()
    if source ~= 65535 then return end
    CreateThread(open)
end)
