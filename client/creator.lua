
local APP_ID = 'kora_crafting:creator'

local data = { recipes = {}, stations = {}, items = {}, skills = {} }
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
    Kora.notify.send({ title = Kora.lang('creator_title'), message = message, type = 'error' })
end

local function confirmed(title, message)
    local answer = Kora.nui.openAlert({ title = title, message = message, confirmLabel = Kora.lang('creator.delete') })
    return answer and answer.confirmed == true
end

local function askName(title, label)
    local result = Kora.nui.openInputDialog({
        { id = 'name', label = label, type = 'text', required = true },
    }, title, Kora.lang('creator.change_later'))
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
    if not recipe.receive then return Kora.lang('creator.makes_nothing') end
    return Kora.lang('player.makes', recipe.receive.amount, itemLabel(recipe.receive.item))
end

local function needsText(recipe)
    local parts = {}
    for _, entry in ipairs(recipe.give) do
        parts[#parts + 1] = ('%dx %s'):format(entry.amount, itemLabel(entry.item))
    end
    return #parts > 0 and table.concat(parts, ', ') or Kora.lang('player.nothing')
end

local function skillLabel(name)
    for _, skill in ipairs(data.skills) do
        if skill.value == name then return skill.label end
    end
    return name
end

local function tagMetadata(recipe, metadata)
    metadata = metadata or {}
    if recipe.tag then metadata[#metadata + 1] = { label = Kora.lang('creator.tag'), value = recipe.tag } end
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
        local metadata = { { label = Kora.lang('player.needs'), value = needsText(recipe) } }
        if recipe.skill then
            metadata[#metadata + 1] = {
                label = Kora.lang('player.skill'),
                value = (recipe.level or 0) > 0 and ('%s · level %d'):format(skillLabel(recipe.skill), recipe.level) or skillLabel(recipe.skill),
            }
        end
        if not recipe.receive then metadata[#metadata + 1] = { label = Kora.lang('creator.status'), value = Kora.lang('creator.recipe_incomplete') } end
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
        id = 'recipes', label = Kora.lang('creator.recipes'), icon = 'FlaskConical',
        content = {
            title = Kora.lang('creator.recipes'),
            description = Kora.lang('creator.recipes_description'),
            blocks = {
                {
                    type = 'actions',
                    actions = { { id = 'recipe:new', label = Kora.lang('creator.create_recipe'), icon = 'Plus', variant = 'primary' } },
                },
                {
                    type = 'list', id = 'recipe-list', layout = 'cards', columns = 3,
                    title = Kora.lang('creator.recipe_count', #items), items = items,
                    empty = Kora.lang('creator.no_recipes'),
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
        if isResult then metadata[#metadata + 1] = { label = Kora.lang('creator.result'), value = Kora.lang('creator.this_result') } end
        if result.added then metadata[#metadata + 1] = { label = Kora.lang('player.needs'), value = Kora.lang('creator.in_recipe') } end

        local actions = {}
        if not isResult then
            actions[#actions + 1] = { id = 'recipe:pick:' .. result.name, label = Kora.lang('creator.set_result'), icon = 'Check', variant = 'primary' }
        end
        if not result.added then
            actions[#actions + 1] = { id = 'recipe:add:' .. result.name, label = Kora.lang('creator.add_recipe'), icon = 'Plus', variant = 'primary' }
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
        { id = 'label', label = Kora.lang('creator.recipe_name'), type = 'text', required = true, default = recipe.label },
        { id = 'tag', label = Kora.lang('creator.tag'), type = 'text', default = recipe.tag or '',
            description = Kora.lang('creator.tag_description') },
    }
    if recipe.receive then
        fields[#fields + 1] = { id = 'amount', label = Kora.lang('creator.amount_made'), type = 'number', min = 1, max = 1000, default = recipe.receive.amount }
    end

    fields[#fields + 1] = { id = 'progressLabel', label = Kora.lang('creator.progress_text'), type = 'text', default = progress.label or '',
        description = Kora.lang('creator.progress_description') }
    fields[#fields + 1] = { id = 'progressTime', label = Kora.lang('creator.progress_time'), type = 'number', min = 500, max = 300000, default = progress.time or 5000 }
    fields[#fields + 1] = { id = 'animDict', label = Kora.lang('creator.anim_dict'), type = 'text', default = anim.dict or '',
        description = Kora.lang('creator.anim_dict_description') }
    fields[#fields + 1] = { id = 'animClip', label = Kora.lang('creator.anim_clip'), type = 'text', default = anim.clip or '',
        description = Kora.lang('creator.anim_clip_description') }
    fields[#fields + 1] = { id = 'animFlag', label = Kora.lang('creator.anim_flag'), type = 'number', min = 0, max = 65535, default = anim.flag or 49,
        description = Kora.lang('creator.anim_flag_description') }
    fields[#fields + 1] = { id = 'disable', label = Kora.lang('creator.disable'), type = 'multiselect', options = ProgressDisableOptions,
        default = disableList(progress.disable), description = Kora.lang('creator.disable_description') }

    if #data.skills > 0 or recipe.skill then
        local options, known = { { value = 'none', label = Kora.lang('creator.no_skill') } }, {}
        for _, skill in ipairs(data.skills) do
            options[#options + 1] = skill
            known[skill.value] = true
        end
        if recipe.skill and not known[recipe.skill] then options[#options + 1] = { value = recipe.skill, label = recipe.skill } end

        fields[#fields + 1] = { id = 'skill', label = Kora.lang('player.skill'), type = 'select', options = options, default = recipe.skill or 'none',
            description = Kora.lang('creator.skill_description') }
    else
        fields[#fields + 1] = { id = 'skill', label = Kora.lang('player.skill'), type = 'text', default = '',
            description = Kora.lang('creator.skill_unavailable') }
    end
    fields[#fields + 1] = { id = 'level', label = Kora.lang('creator.level_required'), type = 'number', min = 0, max = 1000, default = recipe.level,
        description = Kora.lang('creator.level_description') }
    fields[#fields + 1] = { id = 'xp', label = Kora.lang('creator.xp_given'), type = 'number', min = 0, max = 100000, default = recipe.xp,
        description = Kora.lang('creator.xp_description') }

    return {
        type = 'form', id = blockId('recipe-details', recipe.id), title = Kora.lang('creator.details'),
        fields = fields,
        action = { id = 'recipe:details', label = Kora.lang('creator.save') },
    }
end

local function recipeView()
    local recipe = recipeEntry(selectedRecipe)
    if not recipe then
        return {
            id = 'recipe', label = Kora.lang('creator.recipe'), icon = 'FlaskConical',
            content = { title = Kora.lang('creator.recipe'), blocks = { { type = 'empty', title = Kora.lang('creator.pick_recipe') } } },
        }
    end

    local blocks = { detailsForm(recipe) }
    local makes = recipe.receive
    blocks[#blocks + 1] = {
        type = 'list', id = 'recipe-makes', layout = 'cards', columns = 3, title = Kora.lang('creator.what_makes'),
        items = makes and { {
            id = makes.item, label = itemLabel(makes.item), description = makes.item, image = itemImage(makes.item),
            metadata = { { label = Kora.lang('creator.amount'), value = ('%dx'):format(makes.amount) } },
        } } or {},
        empty = Kora.lang('creator.nothing_chosen'),
    }

    local found = resultCards(itemSearch.results, recipe)
    blocks[#blocks + 1] = {
        type = 'form', id = 'recipe-search', title = Kora.lang('creator.find_items'),
        fields = { { id = 'query', label = Kora.lang('creator.search_items'), type = 'text', default = itemSearch.query or '',
            description = Kora.lang('creator.search_items_description') } },
        action = { id = 'recipe:search', label = Kora.lang('creator.search') },
    }
    if itemSearch.query then
        local extra = itemSearch.total > #found and (' of ' .. itemSearch.total) or ''
        blocks[#blocks + 1] = {
            type = 'list', id = 'recipe-results', layout = 'cards', columns = 3,
            title = Kora.lang('creator.results', itemSearch.query, #found, extra),
            items = found, empty = Kora.lang('creator.no_item_matches'),
        }
    end

    local required = {}
    for _, entry in ipairs(recipe.give) do
        local info = data.items[entry.item]
        required[#required + 1] = {
            id = entry.item,
            label = itemLabel(entry.item),
            description = info and entry.item or (entry.item .. Kora.lang('creator.not_shared_item')),
            image = itemImage(entry.item),
            metadata = {
                { label = Kora.lang('creator.amount'), value = ('%dx'):format(entry.amount) },
                entry.keep and { label = Kora.lang('creator.used_up'), value = Kora.lang('creator.kept') } or nil,
            },
            actions = {
                { id = 'recipe:edit:' .. entry.item, label = Kora.lang('creator.edit'), icon = 'Pencil', variant = 'primary' },
                { id = 'recipe:remove:' .. entry.item, label = Kora.lang('creator.remove'), icon = 'Trash2', variant = 'destructive' },
            },
        }
    end
    blocks[#blocks + 1] = {
        type = 'list', id = 'recipe-required', layout = 'cards', columns = 3,
        title = Kora.lang('creator.required_items', #required),
        items = required, empty = Kora.lang('creator.no_requirements'),
    }

    blocks[#blocks + 1] = {
        type = 'actions',
        actions = { { id = 'recipe:duplicate', label = Kora.lang('creator.duplicate_recipe'), icon = 'Copy', variant = 'primary' } },
    }
    blocks[#blocks + 1] = {
        type = 'actions', title = Kora.lang('creator.danger'),
        actions = { { id = 'recipe:delete', label = Kora.lang('creator.delete_recipe'), variant = 'destructive' } },
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
            description = Kora.lang('creator.station_count', #station.recipes, #station.locations),
            action = 'station:select:' .. station.id,
        }
    end

    return {
        id = 'stations', label = Kora.lang('creator.stations'), icon = 'Hammer',
        content = {
            title = Kora.lang('creator.station_title'),
            description = Kora.lang('creator.stations_description'),
            blocks = {
                {
                    type = 'actions',
                    actions = { { id = 'station:new', label = Kora.lang('creator.create_station'), icon = 'Plus', variant = 'primary' } },
                },
                {
                    type = 'list', id = 'station-list', layout = 'cards', columns = 3,
                    title = Kora.lang('creator.station_total', #items), items = items,
                    empty = Kora.lang('creator.no_stations'),
                },
            },
        },
    }
end

local function stationView()
    local station = stationEntry(selectedStation)
    if not station then
        return {
            id = 'station', label = Kora.lang('creator.station'), icon = 'Hammer',
            content = { title = Kora.lang('creator.station'), blocks = { { type = 'empty', title = Kora.lang('creator.pick_station') } } },
        }
    end

    local onStation, taken = {}, {}
    for _, id in ipairs(station.recipes) do
        local recipe = recipeEntry(id)
        if recipe then
            taken[id] = true
            local tags = tagMetadata(recipe)
            onStation[#onStation + 1] = {
                id = id, label = recipe.label, description = makesText(recipe),
                image = recipe.receive and itemImage(recipe.receive.item) or nil,
                metadata = #tags > 0 and tags or nil,
                actions = { { id = 'station:remove:' .. id, label = Kora.lang('creator.remove'), icon = 'Trash2', variant = 'destructive' } },
            }
        end
    end

    local available = {}
    for _, recipe in ipairs(data.recipes) do
        if not taken[recipe.id] and recipeMatches(recipe, stationRecipeQuery) then
            local metadata = tagMetadata(recipe)
            if not recipe.receive then metadata[#metadata + 1] = { label = Kora.lang('creator.status'), value = Kora.lang('creator.recipe_hidden') } end
            available[#available + 1] = {
                id = recipe.id, label = recipe.label, description = makesText(recipe),
                image = recipe.receive and itemImage(recipe.receive.item) or nil,
                metadata = #metadata > 0 and metadata or nil,
                actions = { { id = 'station:add:' .. recipe.id, label = Kora.lang('creator.set_add'), icon = 'Plus', variant = 'primary' } },
            }
        end
    end

    local locations = {}
    for index, location in ipairs(station.locations) do
        local tags = {}
        if location.gang then tags[#tags + 1] = Kora.lang('creator.gang_tag', location.gang) end
        if location.job then tags[#tags + 1] = Kora.lang('creator.job_tag', location.job) end
        if location.object then tags[#tags + 1] = location.object end
        locations[#locations + 1] = {
            id = tostring(index),
            label = Kora.lang('creator.location', index, #tags > 0 and (' · ' .. table.concat(tags, ' · ')) or ''),
            icon = 'MapPin',
            description = coordsLabel(location.coords),
            actions = { { id = 'station:dropLoc:' .. index, label = Kora.lang('creator.delete'), icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'station', label = station.label, icon = 'Hammer',
        content = {
            title = station.label,
            description = Kora.lang('creator.station_description'),
            blocks = {
                {
                    type = 'form', id = blockId('station-details', station.id), title = Kora.lang('creator.settings'),
                    fields = {
                        { id = 'label', label = Kora.lang('creator.station_name'), type = 'text', required = true, default = station.label },
                        { id = 'targetLabel', label = Kora.lang('creator.target_label'), type = 'text', default = station.targetLabel or Kora.lang('player.craft') },
                        { id = 'targetIcon', label = Kora.lang('creator.target_icon'), type = 'text', default = station.targetIcon or 'fa-solid fa-hammer' },
                    },
                    action = { id = 'station:details', label = Kora.lang('creator.save') },
                },
                {
                    type = 'list', id = 'station-recipes', layout = 'cards', columns = 3,
                    title = Kora.lang('creator.station_recipes', #onStation), items = onStation,
                    empty = Kora.lang('creator.station_empty'),
                },
                {
                    type = 'form', id = 'station-recipe-search', title = Kora.lang('creator.find_recipe'),
                    fields = { { id = 'recipeQuery', label = Kora.lang('creator.search_recipes'), type = 'text', default = stationRecipeQuery,
                        description = Kora.lang('creator.search_recipes_description') } },
                    action = { id = 'station:search', label = Kora.lang('creator.search') },
                },
                {
                    type = 'list', id = 'station-available', layout = 'cards', columns = 3,
                    title = Kora.lang('creator.recipes_available', #available), items = available,
                    empty = stationRecipeQuery ~= '' and Kora.lang('creator.no_recipe_matches') or Kora.lang('creator.every_recipe_added'),
                },
                {
                    type = 'form', id = blockId('station-place', station.id), title = Kora.lang('creator.place_locations'),
                    fields = {
                        { id = 'gang', label = Kora.lang('creator.gang'), type = 'text', default = '',
                            description = Kora.lang('creator.gang_description') },
                        { id = 'job', label = Kora.lang('creator.job'), type = 'text', default = '',
                            description = Kora.lang('creator.job_description') },
                        { id = 'object', label = Kora.lang('creator.object'), type = 'text', default = '',
                            description = Kora.lang('creator.object_description') },
                    },
                    action = { id = 'station:place', label = Kora.lang('creator.place_aim') },
                },
                {
                    type = 'list', id = 'station-locations', layout = 'cards', columns = 3,
                    title = Kora.lang('creator.locations', #locations), items = locations, empty = Kora.lang('creator.no_locations'),
                },
                {
                    type = 'actions',
                    actions = { { id = 'station:duplicate', label = Kora.lang('creator.duplicate_station'), icon = 'Copy', variant = 'primary' } },
                },
                {
                    type = 'actions', title = Kora.lang('creator.danger'),
                    actions = { { id = 'station:delete', label = Kora.lang('creator.delete_station'), variant = 'destructive' } },
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
        { id = 'amount', label = Kora.lang('creator.amount_needed'), type = 'number', min = 1, max = 1000, default = current and current.amount or 1, required = true },
        {
            id = 'keep', label = Kora.lang('creator.used_up_question'), type = 'select',
            default = current and current.keep and 'keep' or 'use',
            options = { { value = 'use', label = Kora.lang('creator.yes_used') }, { value = 'keep', label = Kora.lang('creator.player_keeps') } },
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
    local result, err = change('kora_crafting:creator:recipes:give', recipe.id, give)
    if not result then return fail(err or Kora.lang('message.failed_save')) end

    local updated = recipeEntry(recipe.id)
    local inRecipe = {}
    for _, entry in ipairs(updated and updated.give or {}) do inRecipe[entry.item] = true end
    for _, found in ipairs(itemSearch.results) do found.added = inRecipe[found.name] == true end
    return refresh(notice(message))
end

local function detailsInput(values)
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
        local name = askName(Kora.lang('creator.new_recipe'), Kora.lang('creator.recipe_name'))
        if not name then return refresh() end

        local result, err = change('kora_crafting:creator:recipes:create', name)
        if not result then return fail(err or Kora.lang('message.failed_create_recipe')) end
        return openRecipe(result.id, notice(Kora.lang('message.recipe_created')))
    end

    local selectId = actionId:match('^recipe:select:(.+)$')
    if selectId then
        if not recipeEntry(selectId) then return fail(Kora.lang('error.unknown_recipe')) end
        return openRecipe(selectId)
    end

    local recipe = recipeEntry(selectedRecipe)
    if not recipe then return fail(Kora.lang('creator.pick_recipe')) end

    if actionId == 'recipe:details' then
        local input = detailsInput(values)
        if input.anim.dict ~= '' and not DoesAnimDictExist(input.anim.dict) then return fail(Kora.lang('error.unknown_anim_dict')) end

        local result, err = change('kora_crafting:creator:recipes:details', recipe.id, input)
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.saved')))
    end

    local pickName = actionId:match('^recipe:pick:(.+)$')
    if pickName then
        local result, err = change('kora_crafting:creator:recipes:item', recipe.id, pickName)
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.now_makes', itemLabel(pickName))))
    end

    if actionId == 'recipe:duplicate' then
        local result, err = change('kora_crafting:creator:recipes:duplicate', recipe.id)
        if not result then return fail(err or Kora.lang('message.failed_duplicate_recipe')) end
        return openRecipe(result.id, notice(Kora.lang('message.recipe_duplicated')))
    end

    if actionId == 'recipe:delete' then
        local message = Kora.lang('message.delete_recipe_message', recipe.label)
        if not confirmed(Kora.lang('message.delete_recipe_confirm'), message) then return refresh() end

        local result, err = change('kora_crafting:creator:recipes:delete', recipe.id)
        if not result then return fail(err or Kora.lang('message.failed_delete_recipe')) end
        selectedRecipe, currentView = nil, 'recipes'
        return refresh(notice(Kora.lang('message.recipe_deleted')))
    end

    if actionId == 'recipe:search' then
        local query = text(values.query)
        if query == '' then
            clearItemSearch()
            return refresh()
        end

        local result, err = Kora.callback.trigger('kora_crafting:creator:items:search', query, recipe.id)
        if not result then return fail(err or Kora.lang('message.search_failed')) end
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
        if not found then return fail(Kora.lang('message.search_again')) end

        local picked = askAmount(found.label, Kora.lang('creator.add_to_recipe_title'))
        if not picked then return refresh() end

        local give = giveCopy(recipe)
        give[#give + 1] = { item = addName, amount = picked.amount, keep = picked.keep }
        return saveGive(recipe, give, Kora.lang('message.item_added', picked.amount, found.label))
    end

    local editName = actionId:match('^recipe:edit:(.+)$')
    if editName then
        local give = giveCopy(recipe)
        local entry
        for _, candidate in ipairs(give) do
            if candidate.item == editName then entry = candidate break end
        end
        if not entry then return refresh() end

        local picked = askAmount(itemLabel(editName), Kora.lang('creator.edit_item'), entry)
        if not picked then return refresh() end

        entry.amount, entry.keep = picked.amount, picked.keep
        return saveGive(recipe, give, Kora.lang('message.item_needs', itemLabel(editName), picked.amount))
    end

    local removeName = actionId:match('^recipe:remove:(.+)$')
    if removeName then
        local give = {}
        for _, entry in ipairs(giveCopy(recipe)) do
            if entry.item ~= removeName then give[#give + 1] = entry end
        end
        return saveGive(recipe, give, Kora.lang('message.item_removed', itemLabel(removeName)))
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
        local name = askName(Kora.lang('creator.new_station'), Kora.lang('creator.station_name'))
        if not name then return refresh() end

        local result, err = change('kora_crafting:creator:stations:create', name)
        if not result then return fail(err or Kora.lang('message.failed_create_station')) end
        return openStation(result.id, notice(Kora.lang('message.station_created')))
    end

    local selectId = actionId:match('^station:select:(.+)$')
    if selectId then
        if not stationEntry(selectId) then return fail(Kora.lang('error.unknown_station')) end
        return openStation(selectId)
    end

    local station = stationEntry(selectedStation)
    if not station then return fail(Kora.lang('creator.pick_station')) end

    if actionId == 'station:details' then
        local result, err = change('kora_crafting:creator:stations:details', station.id, {
            label = text(values.label),
            targetLabel = text(values.targetLabel),
            targetIcon = text(values.targetIcon),
        })
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.saved')))
    end

    if actionId == 'station:search' then
        stationRecipeQuery = text(values.recipeQuery)
        return refresh()
    end

    local addId = actionId:match('^station:add:(.+)$')
    if addId then
        local result, err = change('kora_crafting:creator:stations:recipes', station.id, stationRecipeIds(station, nil, addId))
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.recipe_added')))
    end

    local removeId = actionId:match('^station:remove:(.+)$')
    if removeId then
        local result, err = change('kora_crafting:creator:stations:recipes', station.id, stationRecipeIds(station, removeId))
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.recipe_removed')))
    end

    if actionId == 'station:place' then
        local object = optionalText(values.object)
        if object and not IsModelInCdimage(GetHashKey(object)) then return fail(Kora.lang('error.unknown_object_model')) end
        pendingTool = { kind = 'point', object = object, gang = optionalText(values.gang), job = optionalText(values.job) }
        currentView = 'station'
        return { close = true }
    end

    local dropIndex = actionId:match('^station:dropLoc:(%d+)$')
    if dropIndex then
        local result, err = change('kora_crafting:creator:stations:locations', station.id, removedAt(station.locations, tonumber(dropIndex)))
        if not result then return fail(err or Kora.lang('message.failed_save')) end
        return refresh(notice(Kora.lang('message.deleted')))
    end

    if actionId == 'station:duplicate' then
        local result, err = change('kora_crafting:creator:stations:duplicate', station.id)
        if not result then return fail(err or Kora.lang('message.failed_duplicate_station')) end
        return openStation(result.id, notice(Kora.lang('message.station_duplicated')))
    end

    if actionId == 'station:delete' then
        local message = Kora.lang('message.delete_station_message', station.label)
        if not confirmed(Kora.lang('message.delete_station_confirm'), message) then return refresh() end

        local result, err = change('kora_crafting:creator:stations:delete', station.id)
        if not result then return fail(err or Kora.lang('message.failed_delete_station')) end
        selectedStation, currentView = nil, 'stations'
        return refresh(notice(Kora.lang('message.station_deleted')))
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
    title = Kora.lang('creator_title'),
    icon = 'Hammer',
    layout = 'standard',
    width = 1200,
    height = 800,
    defaultView = 'recipes',
    navigation = { { id = 'recipes', label = Kora.lang('creator.recipes'), icon = 'FlaskConical', content = { title = Kora.lang('creator.recipes'), blocks = {} } } },
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
        local result, err = change('kora_crafting:creator:stations:locations', station.id, appended(station.locations, place))
        if not result then
            toast(err or Kora.lang('message.failed_save_location'))
            return
        end
    end
end

local function open()
    local result, err = Kora.callback.trigger('kora_crafting:creator:get')
    if not result then
        toast(err or Kora.lang('message.no_permission'))
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

RegisterNetEvent('kora_crafting:creator:open', function()
    if source ~= 65535 then return end
    CreateThread(open)
end)
