local H = dofile('test/harness.lua')

local registeredExports, events = {}, {}
local zones, scopedEntities = {}, 0
local circleOptions, boxOptions

exports = function(name, callback) registeredExports[name] = callback end
Citizen = { Await = function(value) return value end }
CreateThread = function(callback) callback() end
RegisterNetEvent = function(name, callback) events[name] = callback end
IsNuiFocused = function() return false end

local function zoneHandle(kind, options)
    local handle = {
        kind = kind,
        options = options,
        removed = false,
        remove = function(self) self.removed = true end,
        isInside = function() return true end,
    }
    zones[#zones + 1] = handle
    return handle
end

QB = {
    callback = {
        trigger = function(name)
            if name == 'qbcrafting:server:areasRequested' then return {} end
            return true, {}
        end,
    },
    notify = { send = function() end },
    zones = {
        sphere = function(options) return zoneHandle('sphere', options) end,
        box = function(options) return zoneHandle('box', options) end,
        poly = function(options) return zoneHandle('poly', options) end,
    },
    interact = {
        addCircleZone = function(_, _, _, options)
            circleOptions = options
            return zoneHandle('named-sphere', {})
        end,
        addBoxZone = function(_, _, _, options)
            boxOptions = options
            return zoneHandle('named-box', {})
        end,
        removeZone = function() return true end,
        open = function() return true end,
        close = function() return true end,
        isActive = function() return false end,
    },
    entities = {
        createScoped = function(_, _, options)
            scopedEntities = scopedEntities + 1
            return { options = options, remove = function() end }
        end,
    },
}

dofile('client/main.lua')

H.equal(type(events['qbcrafting:client:areaRegistered']), 'function', 'client registers area sync event')
H.equal(events['qbcrafting:client:areaRegistered']({
    id = 'spawned',
    recipes = { { id = 'board', label = 'Board' } },
    location = {
        type = 'model', model = 'prop_tool_bench02', coords = { x = 1, y = 2, z = 3, w = 90 },
        radius = 2.5, streamRadius = 75,
    },
}), true, 'model area creates client presentation')
H.equal(scopedEntities, 1, 'model area creates one locally scoped prop')
H.equal(zones[#zones].kind, 'named-sphere', 'model area gets a sphere interaction')
H.equal(circleOptions[1].label, 'Craft Board', 'sphere interaction receives the non-empty recipe option array')

H.equal(events['qbcrafting:client:areaRegistered']({
    id = 'existing-box',
    recipes = { { id = 'board', label = 'Board' } },
    location = {
        type = 'box', coords = { x = 1, y = 2, z = 3 }, size = { x = 3, y = 2, z = 2 }, rotation = 45,
    },
}), true, 'existing-world box creates client presentation')
H.equal(boxOptions[1].label, 'Craft Board', 'box interaction receives the non-empty recipe option array')

H.equal(events['qbcrafting:client:areaRegistered']({
    id = 'existing-poly',
    recipes = { { id = 'board', label = 'Board' } },
    location = {
        type = 'poly', points = { { x = 0, y = 0, z = 0 }, { x = 2, y = 0, z = 0 }, { x = 2, y = 2, z = 0 } },
        minZ = 0, maxZ = 3,
    },
}), true, 'existing-world poly creates client presentation')
H.equal(zones[#zones].kind, 'poly', 'poly area uses the poly zone primitive')

H.finish()
