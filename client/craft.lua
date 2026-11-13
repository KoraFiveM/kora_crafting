
local APP_ID = 'kora_crafting:menu'
local menu = { label = Kora.lang('title'), recipes = {} }
local chosen = nil -- the recipe picked in the menu

local function toast(message, kind)
    Kora.notify.send({ title = Kora.lang('title'), message = message, type = kind or 'error' })
end

local function blocked(recipe)
    return recipe.locked ~= nil or recipe.missing == true
end

local maxShown = 3
local function summary(materials)
    local parts = {}
    for index, material in ipairs(materials) do
        if index > maxShown then
            parts[#parts + 1] = Kora.lang('player.more', #materials - maxShown)
            break
        end
        parts[#parts + 1] = ('%dx %s'):format(material.amount, material.label)
    end
    return table.concat(parts, ', ')
end

local function materialRows(recipe)
    if #recipe.give == 0 then return { { label = Kora.lang('player.needs'), value = Kora.lang('player.nothing'), tone = 'success' } } end

    local lacking = {}
    for _, material in ipairs(recipe.give) do
        if not material.has then lacking[#lacking + 1] = material end
    end

    local rows = { { label = Kora.lang('player.needs'), value = summary(recipe.give), tone = #lacking == 0 and 'success' or nil } }
    if #lacking > 0 then
        rows[#rows + 1] = { label = Kora.lang('player.missing'), value = summary(lacking), tone = 'destructive' }
    end
    return rows
end

local function recipeCard(recipe)
    local metadata = materialRows(recipe)

    if recipe.skill then
        metadata[#metadata + 1] = {
            label = Kora.lang('player.skill'),
            value = (recipe.level or 0) > 0 and Kora.lang('player.level', recipe.skill, recipe.level) or recipe.skill,
            tone = recipe.locked and 'destructive' or nil,
        }
    end

    local label = recipe.makes.label
    if (recipe.xp or 0) > 0 then label = Kora.lang('player.xp', label, recipe.xp) end

    return {
        id = recipe.id,
        label = label,
        description = Kora.lang('player.makes', recipe.makes.amount, recipe.makes.label),
        image = recipe.makes.image,
        metadata = metadata,
        actions = not blocked(recipe) and {
            { id = 'craft:' .. recipe.id, label = Kora.lang('player.craft'), icon = 'Hammer', variant = 'primary' },
        } or {},
    }
end

local function buildNavigation()
    table.sort(menu.recipes, function(a, b) return a.makes.label:lower() < b.makes.label:lower() end)

    local ready, waiting = {}, {}
    for _, recipe in ipairs(menu.recipes) do
        local list = blocked(recipe) and waiting or ready
        list[#list + 1] = recipeCard(recipe)
    end

    local blocks = {}
    if #ready > 0 then
        blocks[#blocks + 1] = {
            type = 'list', id = 'craft-ready', layout = 'cards', columns = 2,
            title = Kora.lang('player.ready', #ready), items = ready, searchable = #ready > 6,
        }
    end
    if #waiting > 0 then
        blocks[#blocks + 1] = {
            type = 'list', id = 'craft-waiting', layout = 'cards', columns = 2,
            title = Kora.lang('player.waiting', #waiting), items = waiting, searchable = #waiting > 6,
        }
    end
    if #blocks == 0 then
        blocks[1] = { type = 'empty', title = Kora.lang('player.no_recipes') }
    end

    return {
        {
            id = 'recipes', label = menu.label, icon = 'Hammer',
            content = {
                title = menu.label,
                description = #ready > 0 and Kora.lang('player.pick_craft') or Kora.lang('player.cannot_craft'),
                blocks = blocks,
            },
        },
    }
end

Kora.nui.registerApp({
    id = APP_ID,
    title = Kora.lang('title'),
    icon = 'Hammer',
    layout = 'compact',
    placement = 'right',
    width = 640,
    height = 720,
    defaultView = 'recipes',
    navigation = { { id = 'recipes', label = Kora.lang('title'), icon = 'Hammer', content = { title = Kora.lang('title'), blocks = {} } } },
    onAction = function(actionId)
        local id = actionId:match('^craft:(.+)$')
        if id then
            chosen = id
            return { close = true }
        end
        return {}
    end,
})

local function runCraft(stationId, key, recipeId)
    local started, err = Kora.callback.trigger('kora_crafting:begin', stationId, key, recipeId)
    if not started then
        toast(err or Kora.lang('player.cannot_use'))
        return false
    end

    local anim
    if started.anim then
        anim = { dict = started.anim.dict, clip = started.anim.clip, flag = started.anim.flag }
    end

    local done = Kora.progressbar.start({
        label = started.label,
        duration = started.time,
        disable = started.disable or DefaultProgress.disable,
        anim = anim,
    })
    if not done then
        TriggerServerEvent('kora_crafting:server:cancel')
        return false
    end

    local ok, message = Kora.callback.trigger('kora_crafting:finish')
    if not ok then
        toast(message or Kora.lang('player.failed'))
        return false
    end
    return true
end

function OpenCrafting(stationId, key)
    if Crafting then return end
    Crafting = true

    CreateThread(function()
        while true do
            local result, err = Kora.callback.trigger('kora_crafting:menu', stationId, key)
            if not result then
                toast(err or Kora.lang('player.cannot_use_station'))
                break
            end

            menu = { label = result.label or Kora.lang('player.ready_fallback'), recipes = result.recipes or {} }
            chosen = nil
            Kora.nui.updateApp(APP_ID, { navigation = buildNavigation() })
            Kora.nui.openApp(APP_ID, { viewId = 'recipes' })

            if not chosen then break end
            runCraft(stationId, key, chosen)
        end
        Crafting = false
    end)
end
