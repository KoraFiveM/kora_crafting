local function craftability(id)
    if type(id) ~= 'string' then return nil, 'invalid craftable id' end
    local ok, result = pcall(function()
        return Citizen.Await(QB.callback.trigger('qbcrafting:server:craftability', id))
    end)
    if not ok then return nil, tostring(result) end
    return result
end

---@param id string
---@return boolean, string|nil
local function canCraftItem(id)
    local result, err = craftability(id)
    if not result then return false, err end
    return result.canCraft == true, result.reason
end

---@param id string
---@return table|nil, table|string|nil
local function getCraftingRequirements(id)
    local result, err = craftability(id)
    if not result then return nil, err end
    return result.requirements, result.skills
end

exports('CanCraftItem', canCraftItem)
exports('GetCraftingRequirements', getCraftingRequirements)

local APP_ID = 'qbcrafting:bench'
local liveAreas = {}
local activeSnapshot
local appOpening = false

local function notify(message, kind)
    QB.notify.send({ title = 'Crafting', message = message, type = kind or 'error' })
end

local function displayName(value)
    local name = tostring(value or ''):gsub('[_%-]+', ' ')
    return name:gsub('^%l', string.upper)
end

local function outputSummary(outputs)
    local labels = {}
    for _, output in ipairs(outputs or {}) do
        labels[#labels + 1] = ('%dx %s'):format(output.amount, output.label)
    end
    return table.concat(labels, ', ')
end

local function transactionSummary(entries)
    local labels = {}
    for _, entry in ipairs(entries or {}) do
        labels[#labels + 1] = ('%dx %s'):format(entry.amount, entry.label)
    end
    return table.concat(labels, ', ')
end

local function recipeMetadata(recipe)
    local metadata = {
        { label = 'Output', value = outputSummary(recipe.outputs) },
    }
    for _, requirement in ipairs(recipe.requirements or {}) do
        metadata[#metadata + 1] = {
            label = requirement.label,
            value = ('%d / %d'):format(requirement.have, requirement.required),
            tone = requirement.satisfied and 'success' or 'destructive',
        }
    end
    for _, skill in ipairs(recipe.skills or {}) do
        metadata[#metadata + 1] = {
            label = displayName(skill.skill),
            value = ('Level %d'):format(skill.level),
            tone = skill.satisfied and 'success' or 'destructive',
        }
    end
    for skill, amount in pairs(recipe.skillRewards or {}) do
        metadata[#metadata + 1] = {
            label = displayName(skill) .. ' XP',
            value = ('+%d'):format(amount),
            tone = 'primary',
        }
    end
    return metadata
end

local function recipeById(id)
    for _, recipe in ipairs(activeSnapshot and activeSnapshot.recipes or {}) do
        if recipe.id == id then return recipe end
    end
end

local function appDefinition()
    local snapshot = activeSnapshot or { label = 'Crafting', recipes = {} }
    local cards, available = {}, 0
    for _, recipe in ipairs(snapshot.recipes) do
        if recipe.canCraft then available = available + 1 end
        local primaryOutput = recipe.outputs[1]
        local status = recipe.canCraft and 'All requirements are satisfied.'
            or (recipe.reason or 'Requirements are not satisfied.')
        cards[#cards + 1] = {
            id = recipe.id,
            label = recipe.label,
            description = primaryOutput and primaryOutput.description
                and (primaryOutput.description .. ' ' .. status) or status,
            image = primaryOutput and primaryOutput.image or nil,
            icon = 'Hammer',
            badge = recipe.canCraft and 'Ready' or 'Unavailable',
            tone = recipe.canCraft and 'success' or 'neutral',
            metadata = recipeMetadata(recipe),
            actions = {
                {
                    id = 'qbcrafting:craft',
                    label = recipe.canCraft and 'Choose amount' or 'Cannot craft',
                    icon = 'Hammer',
                    variant = recipe.canCraft and 'primary' or 'secondary',
                    disabled = not recipe.canCraft,
                    closeBeforeAction = true,
                    confirm = ('Remove the required ingredients and craft %s?'):format(recipe.label),
                    fields = {
                        {
                            id = 'amount',
                            label = 'Craft amount',
                            type = 'number',
                            required = true,
                            min = 1,
                            max = math.max(1, recipe.maxCraftAmount or 1),
                            default = 1,
                            step = 1,
                            presets = { { value = 1 }, { value = math.max(1, recipe.maxCraftAmount or 1), label = 'Max' } },
                        },
                    },
                },
            },
        }
    end

    local blocks = {
        {
            type = 'stats',
            items = {
                { label = 'Recipes', value = #cards, icon = 'BookOpen' },
                { label = 'Craftable now', value = available, icon = 'CircleCheck', tone = available > 0 and 'success' or 'neutral' },
                { label = 'Station', value = snapshot.label, icon = 'Hammer', tone = 'primary' },
            },
        },
    }
    blocks[#blocks + 1] = {
        type = 'list',
        id = 'crafting-recipes',
        title = 'Craftables',
        layout = 'cards',
        searchable = true,
        scrollable = true,
        searchPlaceholder = 'Search recipes, ingredients, or skills…',
        items = cards,
        empty = 'This station has no recipes.',
    }

    return {
        id = APP_ID,
        title = snapshot.label,
        description = 'Crafting workbench',
        icon = 'Hammer',
        width = 1040,
        height = 760,
        navigation = {
            {
                id = 'recipes',
                label = 'Recipes',
                icon = 'BookOpen',
                badge = #cards,
                content = {
                    title = 'Available recipes',
                    description = 'Ingredient counts and skill requirements reflect your current character and inventory.',
                    scrollable = false,
                    blocks = blocks,
                },
            },
        },
        footer = 'Inventory, access rules, and station proximity are verified again by the server when crafting.',
        onAction = function(actionId, context)
            if actionId ~= 'qbcrafting:craft' then error('Unknown crafting action.') end
            local recipe = recipeById(context and context.itemId)
            local areaId = context and context.data and context.data.areaId
            if not recipe or not recipe.canCraft or areaId ~= activeSnapshot.id then
                error('That recipe is no longer available.')
            end
            local amount = math.floor(tonumber(context.value and context.value.amount) or 0)
            if amount < 1 or amount > (recipe.maxCraftAmount or 0) then
                error('Choose a valid crafting amount.')
            end

            local duration = math.min(7500, 2000 + (amount - 1) * 250)
            local completed, progressErr = QB.progressbar.start({
                label = ('Crafting %dx %s'):format(amount, recipe.label),
                duration = duration,
                canCancel = true,
                disable = { move = true, combat = true, car = true },
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped',
                    flag = 1,
                },
                props = {
                    {
                        model = 'prop_tool_hammer',
                        bone = 57005,
                        offset = { x = 0.12, y = 0.02, z = -0.02 },
                        rotation = { x = -90.0, y = 0.0, z = 0.0 },
                    },
                },
            })
            if not completed then
                return {
                    notice = {
                        tone = progressErr and 'destructive' or 'warning',
                        message = progressErr or 'Crafting cancelled.',
                    },
                }
            end

            local request = table.pack(pcall(QB.callback.trigger,
                'qbcrafting:server:areaCraftRequested', areaId, recipe.id, amount))
            if not request[1] then error(request[2]) end
            local crafted, result, _, confirmation = table.unpack(request, 2, request.n)
            local successMessage = confirmation and ('Removed %s. Received %s.'):format(
                transactionSummary(confirmation.removed), transactionSummary(confirmation.received))
                or ('Crafted %dx %s.'):format(amount, recipe.label)
            return {
                notice = {
                    tone = crafted and 'success' or 'destructive',
                    message = crafted and successMessage
                        or tostring(result or 'Crafting failed.'),
                },
            }
        end,
    }
end

local function openCrafting(area)
    if appOpening or QB.nui.isAppOpen(APP_ID) then return end
    appOpening = true
    CreateThread(function()
        local ok, err = pcall(function()
            local snapshot, snapshotErr = QB.callback.trigger('qbcrafting:server:areaSnapshotRequested', area.id)
            if type(snapshot) ~= 'table' then return notify(snapshotErr or 'This crafting station is unavailable.') end
            activeSnapshot = snapshot
            QB.nui.registerApp(appDefinition())
            QB.nui.openApp(APP_ID, { data = { areaId = area.id } })
        end)

        activeSnapshot = nil
        appOpening = false
        if not ok then
            print(('^1[qbcrafting]^7 failed to open crafting: %s'):format(tostring(err)))
            notify('The crafting interface could not be opened.')
        end

        -- Named sphere/box interactions reopen themselves after focused UI
        -- closes. Poly areas use the raw zone primitive and need this handoff.
        local live = liveAreas[area.id]
        if live and not live.named and live.zone.isInside() and not IsNuiFocused() then
            QB.interact.open(live.options)
        end
    end)
end

local function interactionOptions(area)
    return {
        {
            label = 'Open Crafting',
            icon = 'Hammer',
            action = function() openCrafting(area) end,
        },
    }
end

local function zoneOptions(area, onEnter, onExit)
    local location = area.location
    if location.type == 'model' or location.type == 'sphere' then
        return {
            coords = location.coords,
            radius = location.radius,
            debug = location.debug,
            onEnter = onEnter,
            onExit = onExit,
        }
    end
    if location.type == 'box' then
        return {
            coords = location.coords,
            size = location.size,
            rotation = location.rotation,
            debug = location.debug,
            onEnter = onEnter,
            onExit = onExit,
        }
    end
    return {
        points = location.points,
        minZ = location.minZ,
        maxZ = location.maxZ,
        debug = location.debug,
        onEnter = onEnter,
        onExit = onExit,
    }
end

local function removeArea(id)
    local live = liveAreas[id]
    if not live then return false end
    if live.named then
        QB.interact.removeZone(live.name)
    elseif live.zone then
        live.zone.remove()
    end
    if live.entity then live.entity.remove() end
    liveAreas[id] = nil
    if activeSnapshot and activeSnapshot.id == id then QB.nui.closeApp(APP_ID) end
    return true
end

local function registerArea(area)
    if type(area) ~= 'table' or type(area.id) ~= 'string' or type(area.location) ~= 'table' then return false end
    removeArea(area.id)

    local name = 'qbcrafting:' .. area.id
    local options = interactionOptions(area)
    local function enter() QB.interact.open(options) end
    local function exit()
        if QB.interact.isActive() then QB.interact.close() end
    end
    local location = area.location
    local live = { name = name, options = options }
    if location.type == 'model' or location.type == 'sphere' then
        live.zone = QB.interact.addCircleZone(name, location.coords, location.radius, options, location.debug)
        live.named = true
    elseif location.type == 'box' then
        local size = { x = location.size.x, y = location.size.y, z = location.size.z, w = location.rotation }
        live.zone = QB.interact.addBoxZone(name, location.coords, size, options, location.debug)
        live.named = true
    else
        live.zone = QB.zones.poly(zoneOptions(area, enter, exit))
    end
    if location.type == 'model' then
        live.entity = QB.entities.createScoped(location.model, location.coords, {
            radius = location.streamRadius,
            heading = location.coords.w,
            preset = 'static',
        })
    end
    liveAreas[area.id] = live
    return true
end

RegisterNetEvent('qbcrafting:client:areaRegistered', registerArea)
RegisterNetEvent('qbcrafting:client:areaRemoved', removeArea)

CreateThread(function()
    local areas, err = QB.callback.trigger('qbcrafting:server:areasRequested')
    if type(areas) ~= 'table' then
        return print(('^1[qbcrafting]^7 failed to load crafting areas: %s'):format(tostring(err)))
    end
    for _, area in ipairs(areas) do registerArea(area) end
end)
