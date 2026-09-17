Config = {}

-- Static recipes use the same shape as RegisterCraftable. Functions, including
-- pre/post hooks, are allowed because this file is loaded on the server only.
Config.craftables = {
    wire_bundle = {
        label = 'Wire Bundle',
        take = { { item = 'copper', amount = 2 }, { item = 'plastic', amount = 1 } },
        give = { { item = 'wire_bundle', amount = 1 } },
        skillRewards = { crafting = 10 },
    },
    metal_bracket = {
        label = 'Metal Bracket',
        take = { { item = 'iron', amount = 2 }, { item = 'steel', amount = 1 } },
        give = { { item = 'metal_bracket', amount = 1 } },
        skillRewards = { crafting = 12 },
    },
    electronics_kit = {
        label = 'Electronics Kit',
        take = { { item = 'wire_bundle', amount = 2 }, { item = 'plastic', amount = 2 }, { item = 'glass', amount = 1 } },
        give = { { item = 'electronics_kit', amount = 1 } },
        skills = { crafting = 2 },
        skillRewards = { crafting = 20 },
    },
    vehicle_repair_kit = {
        label = 'Vehicle Repair Kit',
        take = { { item = 'metal_bracket', amount = 2 }, { item = 'rubber', amount = 2 }, { item = 'plastic', amount = 1 } },
        give = { { item = 'vehicle_repair_kit', amount = 1 } },
        skills = { crafting = 3 },
        skillRewards = { crafting = 30 },
    },
}

-- A model area creates a local, scoped prop on every client. A zone area uses
-- an existing world object/interior and supports box, sphere, or poly geometry.
-- Job/gang grade numbers follow qbcore's modern one-based PlayerData grades.
Config.areas = {
    public_workbench = {
        label = 'Public Workbench',
        recipes = { 'wire_bundle', 'metal_bracket', 'electronics_kit' },
        model = 'prop_tool_bench02',
        coords = vector4(1010.16, -1310.17, 35.55, 180.0),
        radius = 2.5,
        streamRadius = 75.0,
        rules = { skills = { crafting = 1 } },
    },
    mechanic_workshop = {
        label = 'Mechanic Workshop Bench',
        recipes = { 'metal_bracket', 'electronics_kit', 'vehicle_repair_kit' },
        zone = {
            type = 'box',
            coords = vector3(-345.19, -133.40, 39.01),
            size = vector3(3.0, 2.0, 2.5),
            rotation = 70.0,
        },
        rules = {
            jobs = { mechanic = 1 },
            onDuty = true,
        },
    },
}

-- Registers this resource-owned configuration with qblib.
if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
