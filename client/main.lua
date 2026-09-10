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

local liveAreas = {}

local function notify(message, kind)
    QB.notify.send({ title = 'Crafting', message = message, type = kind or 'error' })
end

local function requestCraft(area, recipe)
    CreateThread(function()
        local crafted, result = QB.callback.trigger('qbcrafting:server:areaCraftRequested', area.id, recipe.id)
        if crafted then
            notify(('Crafted %s.'):format(recipe.label), 'success')
        else
            notify(tostring(result or 'Crafting failed.'))
        end

        -- Named sphere/box interactions reopen themselves. Poly areas use the
        -- raw zone primitive, so restore their selector after the action.
        local live = liveAreas[area.id]
        if live and not live.named and live.zone.isInside() and not IsNuiFocused() then
            QB.interact.open(live.options)
        end
    end)
end

local function interactionOptions(area)
    local options = {}
    for _, recipe in ipairs(area.recipes) do
        local selected = recipe
        options[#options + 1] = {
            label = ('Craft %s'):format(selected.label),
            action = function() requestCraft(area, selected) end,
        }
    end
    return options
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
