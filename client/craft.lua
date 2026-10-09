
local APP_ID = 'qbcrafting:menu'
local menu = { label = 'Crafting', recipes = {} }
local chosen = nil -- the recipe picked in the menu

local function toast(message, kind)
    QB.notify.send({ title = 'Crafting', message = message, type = kind or 'error' })
end

local function needsText(recipe)
    local parts = {}
    for _, material in ipairs(recipe.give) do
        parts[#parts + 1] = ('%dx %s%s'):format(material.amount, material.label, material.keep and ' (kept)' or '')
    end
    return #parts > 0 and table.concat(parts, ', ') or 'Nothing'
end

local function buildNavigation()
    local items = {}
    table.sort(menu.recipes, function(a, b)
        local aBlocked, bBlocked = a.locked or a.missing, b.locked or b.missing
        if not not aBlocked ~= not not bBlocked then return not aBlocked end
        return a.makes.label:lower() < b.makes.label:lower()
    end)
    for _, recipe in ipairs(menu.recipes) do
        local warning = recipe.locked or recipe.missing
        local metadata = { { label = 'Needs', value = needsText(recipe), tone = warning and 'destructive' or 'success' } }
        if recipe.skill then
            metadata[#metadata + 1] = {
                label = 'Skill',
                value = (recipe.level or 0) > 0 and ('%s · level %d'):format(recipe.skill, recipe.level) or recipe.skill,
                tone = warning and 'destructive' or nil,
            }
        end
        if (recipe.xp or 0) > 0 then
            metadata[#metadata + 1] = { label = 'XP', value = '+' .. recipe.xp, tone = warning and 'success' or nil }
        end
        
        if recipe.locked then
            metadata[#metadata + 1] = { label = 'Locked', value = recipe.locked, tone = 'destructive' }
        elseif recipe.missing then
            metadata[#metadata + 1] = { label = 'Status', value = 'Missing materials', tone = 'destructive' }
        end
        items[#items + 1] = {
            id = recipe.id,
            label = recipe.makes.label,
            description = ('Makes %dx %s'):format(recipe.makes.amount, recipe.makes.label),
            image = recipe.makes.image,
            metadata = metadata,
            actions = (recipe.locked or recipe.missing) and {} or {
                { id = 'craft:' .. recipe.id, label = 'Craft', icon = 'Hammer', variant = 'primary' },
            },
        }
    end
    
    return {
        {
            id = 'recipes', label = menu.label, icon = 'Hammer',
            content = {
                title = menu.label,
                description = 'Pick something to craft.',
                blocks = {
                    { type = 'list', id = 'craft-list', layout = 'cards', columns = 3, items = items, empty = 'This station has no recipes yet.' },
                },
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
    width = 500,
    height = 700,
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
