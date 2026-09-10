local H = dofile('test/harness.lua')

local registeredExports, events = {}, {}
local zones, scopedEntities = {}, 0
local circleOptions, boxOptions
local registeredApp, openedApp, actionResult
local appOpen, progressPayload = false
local progressCompleted, craftRequests = true, 0

local function snapshotData()
    return {
        id = 'spawned', label = 'Test Bench', recipes = {
            {
                id = 'board', label = 'Board', canCraft = true,
                outputs = { { item = 'board', label = 'Board', amount = 1, description = 'A wooden board.' } },
                requirements = { { item = 'wood', label = 'Wood', have = 3, required = 2, satisfied = true } },
                skills = { { skill = 'crafting', level = 1, satisfied = true } },
                skillRewards = { crafting = 10 },
                maxCraftAmount = 1,
            },
            {
                id = 'locked', label = 'Locked Item', canCraft = false, reason = 'requires crafting level 5',
                outputs = { { item = 'locked', label = 'Locked Item', amount = 1 } },
                requirements = { { item = 'wood', label = 'Wood', have = 3, required = 5, satisfied = false } },
                skills = { { skill = 'crafting', level = 5, satisfied = false } },
                skillRewards = {},
                maxCraftAmount = 0,
            },
        },
    }
end

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
            if name == 'qbcrafting:server:areaSnapshotRequested' then return snapshotData() end
            if name == 'qbcrafting:server:areaCraftRequested' then
                craftRequests = craftRequests + 1
                return true, snapshotData(), nil, {
                    removed = { { amount = 2, label = 'Wood' } },
                    received = { { amount = 1, label = 'Board' } },
                }
            end
            return true, {}
        end,
    },
    notify = { send = function() end },
    progressbar = {
        start = function(payload)
            progressPayload = payload
            return progressCompleted
        end,
    },
    nui = {
        isAppOpen = function() return appOpen end,
        registerApp = function(definition) registeredApp = definition end,
        openApp = function(id)
            openedApp = id
            appOpen = true
            actionResult = registeredApp.onAction('qbcrafting:craft', {
                itemId = 'board', value = { amount = 1 }, data = { areaId = 'spawned' },
            })
            appOpen = false
            return { closed = true }
        end,
        closeApp = function() return true end,
    },
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
H.equal(#circleOptions, 1, 'sphere interaction exposes one action')
H.equal(circleOptions[1].label, 'Open Crafting', 'sphere interaction opens crafting rather than listing recipes')
circleOptions[1].action()
H.equal(openedApp, 'qbcrafting:bench', 'world interaction opens the crafting AppShell')
H.equal(registeredApp.navigation[1].content.blocks[2].items[1].actions[1].disabled, false,
    'craftable recipe has an enabled craft action')
H.equal(registeredApp.navigation[1].content.blocks[2].items[2].actions[1].disabled, true,
    'uncraftable recipe is greyed out with a disabled craft action')
H.equal(actionResult.notice.tone, 'success', 'crafting action returns an in-shell success notice')
H.equal(registeredApp.navigation[1].content.scrollable, false, 'crafting keeps the AppShell content fixed')
H.equal(registeredApp.navigation[1].content.blocks[2].scrollable, true, 'only the craftables list owns scrolling')
H.equal(registeredApp.navigation[1].content.blocks[2].items[1].actions[1].fields[1].label, 'Craft amount',
    'craft action asks for an amount')
H.equal(registeredApp.navigation[1].content.blocks[2].items[1].actions[1].closeBeforeAction, true,
    'crafting closes the AppShell before starting work')
H.equal(progressPayload.label, 'Crafting 1x Board', 'crafting uses the qblib progress bar')
H.equal(progressPayload.anim.dict, 'mini@repair', 'qblib progress owns the crafting animation')
H.equal(progressPayload.props[1].model, 'prop_tool_hammer', 'qblib progress owns the temporary hammer prop')
H.equal(actionResult.notice.message:find('Removed 2x Wood', 1, true) ~= nil, true,
    'crafting confirms the committed ingredient removal')

progressCompleted = false
circleOptions[1].action()
H.equal(actionResult.notice.message, 'Crafting cancelled.', 'cancelled progress reports cancellation after closing the shell')
H.equal(craftRequests, 1, 'cancelled progress does not request the inventory transaction')

H.equal(events['qbcrafting:client:areaRegistered']({
    id = 'existing-box',
    recipes = { { id = 'board', label = 'Board' } },
    location = {
        type = 'box', coords = { x = 1, y = 2, z = 3 }, size = { x = 3, y = 2, z = 2 }, rotation = 45,
    },
}), true, 'existing-world box creates client presentation')
H.equal(boxOptions[1].label, 'Open Crafting', 'box interaction exposes the single crafting action')

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
