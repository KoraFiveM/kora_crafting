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
