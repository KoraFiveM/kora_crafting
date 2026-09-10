# qbcrafting

`qbcrafting` is an export-driven, server-authoritative recipe registry. It uses
qbinventory's locked crafting transaction, so all ingredients and all outputs
are committed together. A failed check, rejected pre hook, missing ingredient,
slot failure, weight failure, or inventory write failure changes no items.

## Register and craft

Register recipes from server code. The resource that registers an id owns it;
its recipes are removed automatically when that resource stops.

```lua
exports.qbcrafting:RegisterCraftable({
    id = 'repair_kit',
    label = 'Repair kit',
    take = {
        { item = 'metalscrap', amount = 2 },
        { item = 'plastic', amount = 1 },
    },
    give = {
        { item = 'repairkit', amount = 1 },
    },
    skills = { crafting = 5 }, -- Optional; checked through qbskills.
    skillRewards = { crafting = 15 }, -- Optional; awarded after a successful commit.
    hooks = {
        pre = function(source, data)
            -- Only the exact value false cancels. nil permits the craft.
            -- return false, 'This bench is unavailable'
        end,
        post = function(source, data)
            -- Runs after the inventory transaction has committed.
        end,
    },
})

local crafted, resultOrError = exports.qbcrafting:CraftItem(source, 'repair_kit')
local canCraft, reason = exports.qbcrafting:CanCraftItem(source, 'repair_kit')
local items, skills = exports.qbcrafting:GetCraftingRequirements(source, 'repair_kit')
```

`CraftItem` is server-only. A gameplay resource must validate its own station,
distance, routing bucket, job, and action completion before calling it. An
optional third argument may carry server-owned context to the hooks; never pass
raw client-selected authority through it.

`skills` is preferable to repeating ordinary level gates in every pre hook:
it makes `CanCraftItem` and requirement displays accurate. Use `hooks.pre` for
dynamic policy such as a station state, shift, cooldown, or event condition.
When a recipe declares skills and `qbskills` is not running, it fails closed.
`skillRewards` are server-only and are awarded only after the inventory
transaction commits. If qbskills is unavailable, the craft still succeeds and
no XP is awarded.

## Client presentation exports

Both client exports perform an authenticated server callback and may yield:

```lua
local canCraft, reason = exports.qbcrafting:CanCraftItem('repair_kit')
local requirements, skills = exports.qbcrafting:GetCraftingRequirements('repair_kit')
```

Each item requirement contains `item`, `label`, `required`, `have`,
`satisfied`, and `metadata`. Skill rows contain `skill`, `level`, and
`satisfied`. These exports provide presentation data; they do not authorize or
start a craft.

## Crafting areas and benches

`RegisterCraftingArea` is a server export. The server retains its location and
access policy, while qbcrafting sends only presentation data to clients. A
model-backed area is spawned separately by every client as a non-networked,
distance-scoped prop. A zone-backed area adds interaction to an existing prop
or interior without spawning anything.

```lua
exports.qbcrafting:RegisterCraftingArea({
    id = 'mechanic_bench',
    label = 'Mechanic Workbench',
    recipes = { 'vehicle_repair_kit', 'electronics_kit' },
    model = 'prop_tool_bench02',
    coords = vector4(-345.2, -133.4, 39.0, 70.0),
    radius = 2.5,
    streamRadius = 75.0,
    rules = {
        jobs = { mechanic = 1 },
        gangs = { ballas = 2 },
        skills = { crafting = 5 },
        onDuty = true,
        canUse = function(source, area)
            -- Only the exact value false denies access.
            -- return false, 'The workshop is closed'
        end,
    },
})
```

`jobs` and `gangs` accept a single name, an array of names, or a
`name = minimumGrade` map. Grade numbers use qbcore's modern one-based
`PlayerData` grades. When both job and gang rules are present, the player must
satisfy both. Skill rules fail closed when qbskills is unavailable.

Instead of `model` and `coords`, pass one of the existing-world zone shapes:

```lua
zone = {
    type = 'box', -- or 'sphere' / 'poly'
    coords = vector3(-345.2, -133.4, 39.0),
    size = vector3(3.0, 2.0, 2.5),
    rotation = 70.0,
}

zone = {
    type = 'sphere',
    coords = vector3(100.0, 200.0, 30.0),
    radius = 2.5,
}

zone = {
    type = 'poly',
    points = {
        vector3(100.0, 200.0, 30.0),
        vector3(104.0, 200.0, 30.0),
        vector3(104.0, 204.0, 30.0),
    },
    thickness = 3.0, -- or explicit minZ and maxZ
}
```

Every interaction request is checked again on the server against the exact
shape, the area's recipe allow-list, current job/gang/duty/skill state, and the
custom rule before the atomic inventory transaction runs. Areas are owned by
their registering resource and disappear on resource stop. Related server
exports are `RemoveCraftingArea`, `GetCraftingArea`, `CanUseCraftingArea`, and
`CraftAtArea`.
