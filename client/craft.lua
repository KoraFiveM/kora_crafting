
local APP_ID = 'qbcrafting:menu'
local menu = { label = 'Crafting', recipes = {} }
local chosen = nil -- the recipe picked in the menu

local function toast(message, kind)
    QB.notify.send({ title = 'Crafting', message = message, type = kind or 'error' })
end

local function blocked(recipe)
    return recipe.locked ~= nil or recipe.missing == true
end

local maxShown = 3
local function summary(materials)
    local parts = {}
    for index, material in ipairs(materials) do
        if index > maxShown then
            parts[#parts + 1] = ('+%d more'):format(#materials - maxShown)
            break
        end
        parts[#parts + 1] = ('%dx %s'):format(material.amount, material.label)
    end
    return table.concat(parts, ', ')
end

local function materialRows(recipe)
    if #recipe.give == 0 then return { { label = 'Needs', value = 'Nothing', tone = 'success' } } end

    local lacking = {}
    for _, material in ipairs(recipe.give) do
        if not material.has then lacking[#lacking + 1] = material end
    end

    local rows = { { label = 'Needs', value = summary(recipe.give), tone = #lacking == 0 and 'success' or nil } }
    if #lacking > 0 then
        rows[#rows + 1] = { label = 'Missing', value = summary(lacking), tone = 'destructive' }
    end
    return rows
end

local function recipeCard(recipe)
    local metadata = materialRows(recipe)

    if recipe.skill then
        metadata[#metadata + 1] = {
            label = 'Skill',
            value = (recipe.level or 0) > 0 and ('%s · level %d'):format(recipe.skill, recipe.level) or recipe.skill,
            tone = recipe.locked and 'destructive' or nil,
        }
    end

    local label = recipe.makes.label
    if (recipe.xp or 0) > 0 then label = ('%s | %d XP'):format(label, recipe.xp) end

    return {
        id = recipe.id,
        label = label,
        description = ('Makes %dx %s'):format(recipe.makes.amount, recipe.makes.label),
        image = recipe.makes.image,
        metadata = metadata,
        actions = not blocked(recipe) and {
            { id = 'craft:' .. recipe.id, label = 'Craft', icon = 'Hammer', variant = 'primary' },
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
            title = ('Ready to craft (%d)'):format(#ready), items = ready, searchable = #ready > 6,
        }
    end
    if #waiting > 0 then
        blocks[#blocks + 1] = {
            type = 'list', id = 'craft-waiting', layout = 'cards', columns = 2,
            title = ('Missing something (%d)'):format(#waiting), items = waiting, searchable = #waiting > 6,
        }
    end
    if #blocks == 0 then
        blocks[1] = { type = 'empty', title = 'This station has no recipes yet.' }
    end

    return {
        {
            id = 'recipes', label = menu.label, icon = 'Hammer',
            content = {
                title = menu.label,
                description = #ready > 0 and 'Pick something to craft.' or 'You cannot craft anything here yet.',
                blocks = blocks,
            },
        },
    }
end

QB.nui.registerApp({
    id = APP_ID,
    title = 'Crafting',
    icon = 'Hammer',
    layout = 'compact',
    placement = 'right',
    width = 640,
    height = 720,
    defaultView = 'recipes',
    navigation = { { id = 'recipes', label = 'Crafting', icon = 'Hammer', content = { title = 'Crafting', blocks = {} } } },
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
    local started, err = QB.callback.trigger('qbcrafting:begin', stationId, key, recipeId)
    if not started then
        toast(err or 'You cannot craft that.')
        return false
    end

    local anim
    if started.anim then
        anim = { dict = started.anim.dict, clip = started.anim.clip, flag = started.anim.flag, flags = started.anim.flag }
    end

    local done = QB.progressbar.start({
        label = started.label,
        duration = started.time,
        disable = started.disable or DefaultProgress.disable,
        anim = anim,
    })
    if not done then
        TriggerServerEvent('qbcrafting:server:cancel')
        return false
    end

    local ok, message = QB.callback.trigger('qbcrafting:finish')
    if not ok then
        toast(message or 'Crafting failed.')
        return false
    end
    return true
end

function OpenCrafting(stationId, key)
    if Crafting then return end
    Crafting = true

    CreateThread(function()
        while true do
            local result, err = QB.callback.trigger('qbcrafting:menu', stationId, key)
            if not result then
                toast(err or 'You cannot use this station.')
                break
            end

            menu = { label = result.label or 'Crafting', recipes = result.recipes or {} }
            chosen = nil
            QB.nui.updateApp(APP_ID, { navigation = buildNavigation() })
            QB.nui.openApp(APP_ID, { viewId = 'recipes' })

            if not chosen then break end
            runCraft(stationId, key, chosen)
        end
        Crafting = false
    end)
end
