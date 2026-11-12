---
title: "Skills integration"
sidebar_position: 2
---


# Skills integration

A thin, defensive wrapper around one external skills resource, configured by name and export names so it can be pointed at something other than kora_skills.

Namespace: `Config.Skills` · Source: `server/skills.lua, shared/config.lua`

## How it works

Every call goes through `pcall(exports[Config.Skills.resource][exportName], ...)`. The three internal helpers above are not exported by kora_crafting itself; they exist purely so `server/craft.lua`, `server/rules.lua` and `server/creator.lua` can treat "no skills resource" as a soft failure instead of crashing.

## Config.Skills fields

From `shared/config.lua`.

| Option | Type | Description |
| --- | --- | --- |
| `resource` | string | Resource name whose exports are called. Default `'kora_skills'`. |
| `getData` | string | Export returning `{ skillName = 'Skill Label', ... }`, used to build the skill dropdown and labels. Default `'GetSkillsData'`. |
| `getRep` | string | Export `(src, skill) -> { level, ... }`, used to show the player's current level in the menu. Default `'getRep'`. |
| `isLevel` | string | Export `(src, skill, level) -> boolean`, the server-side gate. Default `'isLevel'`. |
| `addRep` | string | Export `(src, skill, amount) -> true, or false and a reason`, called on a successful craft. Default `'addRep'`. |

## Functions

Three internal helper functions and the four export names they call.

### `GetSkills() (internal)`

Returns the raw skill-name → label map from `exports[Config.Skills.resource][Config.Skills.getData]()`, or nil if that export failed.

**Parameters**



**Returns**

- **skills** — table, or nil when the skills resource/export is unavailable.

**Example**

```lua
-- internal to server/skills.lua; not exported by kora_crafting
```

**Representative console output**

```text
Failures are only warned once per export name to avoid log spam.
```

### `HasSkillLevel(src, skill, level) (internal)`

Calls `Config.Skills.isLevel(src, skill, level)` on the configured skills resource.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | number | Player server id. |
| `skill` | string | Skill name. |
| `level` | number | Required level. |

**Returns**

- **true/false** — whether the player meets the level.
- **nil** — the skills export could not be called (treated as "skills unavailable", not as "level not met").

**Example**

```lua
-- internal; used by craftable() in server/craft.lua
```

**Representative console output**

```text
A recipe with `level` set but skills unavailable always fails with "Skills are unavailable right now."
```

### `GiveSkillXp(src, skill, xp) (internal)`

Calls `Config.Skills.addRep(src, skill, xp)` after a successful craft.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | number | Player server id. |
| `skill` | string | Skill name. |
| `xp` | number | Amount to award. |

**Returns**

- **true** — the skills resource accepted the award.
- **false** — the export failed, or the skills resource itself refused the amount (for example above its own cap); a warning is logged once per occurrence key.

**Example**

```lua
-- internal; used by kora_crafting:finish
```

**Representative console output**

```text
kora_skills refuses an amount above its own `Config.maxAward`, per the README.
```

## Limits and related APIs

If `Config.Skills.resource` is not running, or does not expose these exact export names, skill-gated recipes stay usable by everyone with `level` unset, but anyone with a `level` requirement is always refused (skills reported as unavailable). Recipes with a skill and `xp` above 0 try to award XP after a craft and simply fail silently (one warning) if that cannot be reached.

## See also

- [Configuration](../configuration.md) for `Config.Skills` and the limits.
- [Crafting Creator](../creator.md) for the skill dropdown and the free-text fallback.
