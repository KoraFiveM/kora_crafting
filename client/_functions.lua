
Stations = {}    -- id -> { id, label, targetLabel, targetIcon, locations }, kept up to date by the server
Crafting = false -- true while a station menu is open or a craft is running

function canUse(location)
    if not (location.gang or location.job) then return true end
    local player = exports.kora_core:getPlayerData()
    if not player then return false end
    return (location.gang ~= nil and player.gang ~= nil and player.gang.name == location.gang)
        or (location.job ~= nil and player.job ~= nil and player.job.name == location.job)
        or false
end

local function createBox(coords, options)
    return exports.kora_target:addBoxZone({
        coords = coords,
        size = vector3(2, 2, 2),
        rotation = 0,
        options = options,
    })
end

local function createObject(object, coords, options)
    local entity = Kora.entities.create(object, coords, { freeze = true, invincible = true })
    SetEntityHeading(entity, coords.w)
    exports.kora_target:addEntity(entity, options)
    return entity
end

local function removeZones(ids)
    for _, id in ipairs(ids) do
        pcall(function() exports.kora_target:removeZone(id) end)
    end
end

local zones = {} -- station id -> { boxes = { zone ids }, objects = { entities } }

local function clearStation(id)
    local built = zones[id]
    if built then
        removeZones(built.boxes)
        for _, object in ipairs(built.objects) do
            pcall(function() Kora.entities.remove(object) end)
        end
    end
    zones[id] = nil
end

local function buildStation(id, entry)
    clearStation(id)
    Stations[id] = entry
    if type(entry) ~= 'table' or type(entry.locations) ~= 'table' then return end

    local built = { boxes = {}, objects = {} }
    zones[id] = built

    for key, location in ipairs(entry.locations) do
        local c = location.coords
        if c then
            local options = {
                {
                    label = entry.targetLabel or 'Craft',
                    icon = entry.targetIcon or 'fa-solid fa-hammer',
                    onSelect = function() OpenCrafting(id, key) end,
                    canInteract = function() return not Crafting and canUse(location) end,
                },
            }
            if location.object then
                built.objects[#built.objects + 1] = createObject(location.object, vector4(c.x, c.y, c.z, c.w or 0.0), options)
            else
                built.boxes[#built.boxes + 1] = createBox(vector3(c.x, c.y, c.z), options)
            end
        end
    end
end

RegisterNetEvent('qbcrafting:client:stationReload', function(id, entry)
    buildStation(id, entry)
end)

CreateThread(function()
    local all = Kora.state.awaitGlobal('Crafting', 30000, 100)
    if not all then
        print('[qbcrafting] timed out waiting for GlobalState.Crafting')
        return
    end
    for id, entry in pairs(all.stations or {}) do buildStation(id, entry) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(zones) do clearStation(id) end
end)