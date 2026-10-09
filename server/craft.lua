-- What happens when a player crafts. The client only shows the bar: every rule is checked here, twice:
--   begin   everything is checked and the craft starts (the progress time is remembered)
--   finish  after the bar the checks run again, the materials are taken and the item given
-- so a client that skips the bar, or the menu, gets nothing.

local pending = {} -- src -> { station, key, recipe, started, duration, expires }

local function notify(src, message, kind)
    QB.notify.send(src, { title = 'Crafting', message = message, type = kind or 'error' })
end

-- The station location the player is standing at, or nil and a message.
local function resolveStation(src, stationId, key)
    local station = validId(stationId) and Stations[stationId]
    local location = station and type(key) == 'number' and station.locations[key]
    if not location then return nil, 'This station is not available.' end
    if not isNear(src, location.coords) then return nil, 'You are too far away.' end
    if not locationAllowed(src, location) then return nil, 'You cannot use this station.' end
    return station, location
end

local function itemLabel(shared, name)
    local info = itemEntry(shared, name)
    return info and info.label or name
end

-- The recipe, when the player can craft it right now. Otherwise nil and why.
local function craftable(src, station, recipeId)
    if not validId(recipeId) then return nil, 'Unknown recipe.' end

    local onStation = false
    for _, id in ipairs(station.data.recipes) do
        if id == recipeId then onStation = true break end
    end
    local recipe = Recipes[recipeId]
    if not (onStation and recipe and recipeComplete(recipe)) then return nil, 'That recipe is not available here.' end

    local shared = allItems()
    if type(shared[recipe.receive.item]) ~= 'table' then return nil, 'That recipe makes an item that does not exist.' end

    if recipe.skill and (recipe.level or 0) > 0 then
        local has = HasSkillLevel(src, recipe.skill, recipe.level)
        if has == nil then return nil, 'Skills are unavailable right now.' end
        if not has then return nil, ('You need level %d.'):format(recipe.level) end
    end

    local missing = {}
    for _, entry in ipairs(recipe.give) do
        if not exports['qb-inventory']:HasItem(src, entry.item, entry.amount) then
            missing[#missing + 1] = ('%dx %s'):format(entry.amount, itemLabel(shared, entry.item))
        end
    end
    if #missing > 0 then return nil, 'You need ' .. table.concat(missing, ', ') .. '.' end

    return recipe
end

-- Takes the materials that are used up. All of them or none: a failure gives back what was taken.
local function takeItems(src, give)
    local taken = {}
    for _, entry in ipairs(give) do
        if not entry.keep then
            if not exports['qb-inventory']:RemoveItem(src, entry.item, entry.amount) then
                for _, back in ipairs(taken) do exports['qb-inventory']:AddItem(src, back.item, back.amount) end
                return false
            end
            taken[#taken + 1] = entry
        end
    end
    return true, taken
end

-- ----------------------------------------------------------------------------
-- The menu a player sees at a station
-- ----------------------------------------------------------------------------

QB.callback.register('qbcrafting:menu', function(src, stationId, key)
    if not DataLoaded then return false, 'Crafting is still loading.' end
    local station, err = resolveStation(src, stationId, key)
    if not station then return false, err end

    local shared, skills, levels = allItems(), GetSkills() or {}, {}
    local list = {}

    for _, id in ipairs(station.data.recipes) do
        local recipe = Recipes[id]
        if recipe and recipeComplete(recipe) then
            local made = itemEntry(shared, recipe.receive.item)
            local entry = {
                id = id,
                label = recipe.label,
                makes = {
                    item = recipe.receive.item,
                    label = made and made.label or recipe.receive.item,
                    image = made and made.image or nil,
                    amount = recipe.receive.amount,
                },
                give = {},
                missing = false,
                xp = recipe.xp,
                level = recipe.level,
            }

            for _, material in ipairs(recipe.give) do
                local info = itemEntry(shared, material.item)
                local has = exports['qb-inventory']:HasItem(src, material.item, material.amount) and true or false
                if not has then entry.missing = true end
                entry.give[#entry.give + 1] = {
                    item = material.item,
                    label = info and info.label or material.item,
                    amount = material.amount,
                    keep = material.keep,
                    has = has,
                }
            end

            if recipe.skill then
                entry.skill = tostring(skills[recipe.skill] or recipe.skill)
                if (recipe.level or 0) > 0 then
                    if levels[recipe.skill] == nil then levels[recipe.skill] = SkillLevel(src, recipe.skill) or false end
                    local level = levels[recipe.skill]
                    if not level then
                        entry.locked = 'Skills are unavailable right now'
                    elseif level < recipe.level then
                        entry.locked = ('Needs %s level %d (you are level %d)'):format(entry.skill, recipe.level, level)
                    end
                end
            end

            list[#list + 1] = entry
        end
    end

    return { label = station.data.label, recipes = list }
end)

-- ----------------------------------------------------------------------------
-- Crafting
-- ----------------------------------------------------------------------------

QB.callback.register('qbcrafting:begin', function(src, stationId, key, recipeId)
    if not DataLoaded then return false, 'Crafting is still loading.' end

    local now = GetGameTimer()
    if pending[src] and now < pending[src].expires then return false, 'You are already crafting.' end

    local station, err = resolveStation(src, stationId, key)
    if not station then return false, err end
    local recipe, why = craftable(src, station, recipeId)
    if not recipe then return false, why end

    local duration = recipe.progress.time
    pending[src] = {
        station = stationId, key = key, recipe = recipeId,
        started = now, duration = duration, expires = now + duration + 15000,
    }

    local anim = recipe.anim.dict ~= '' and recipe.anim.clip ~= ''
        and { dict = recipe.anim.dict, clip = recipe.anim.clip, flag = recipe.anim.flag } or nil
    return {
        time = duration,
        label = recipe.progress.label ~= '' and recipe.progress.label or DefaultProgress.label,
        disable = recipe.progress.disable,
        anim = anim,
    }
end)

QB.callback.register('qbcrafting:finish', function(src)
    local job = pending[src]
    pending[src] = nil
    if not job then return false, 'Nothing is being crafted.' end

    local now = GetGameTimer()
    if now > job.expires then return false, 'That took too long. Try again.' end
    if now - job.started < job.duration - 1000 then
        QB.print.warn(('[qbcrafting] player %s finished %s in %dms (it takes %dms)'):format(src, job.recipe, now - job.started, job.duration))
        return false, 'You finished too quickly.'
    end

    local station, err = resolveStation(src, job.station, job.key)
    if not station then return false, err end
    local recipe, why = craftable(src, station, job.recipe)
    if not recipe then return false, why end

    local took, taken = takeItems(src, recipe.give)
    if not took then return false, 'Could not take the materials.' end

    if not exports['qb-inventory']:AddItem(src, recipe.receive.item, recipe.receive.amount) then
        for _, back in ipairs(taken) do exports['qb-inventory']:AddItem(src, back.item, back.amount) end
        return false, 'You do not have room for that.'
    end

    if recipe.skill and (recipe.xp or 0) > 0 then GiveSkillXp(src, recipe.skill, recipe.xp) end
    notify(src, ('You made %dx %s.'):format(recipe.receive.amount, itemLabel(allItems(), recipe.receive.item)), 'success')
    return true
end)

-- The player stopped the bar.
RegisterNetEvent('qbcrafting:server:cancel', function()
    pending[source] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
