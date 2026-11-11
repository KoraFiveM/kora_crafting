---
title: Configuration
sidebar_position: 2
---

# Configuration

Recipes and stations are not configured in files. They are made in the [Crafting Creator](./creator.md) and stored in the [database](./database.md). The files below only control the resource's general behaviour. Both are shared scripts, so the client and the server read the same values.

## `shared/config.lua`

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.Command` | string | `'craftCreator'` | Name of the chat command that opens the creator. Using it still needs the `command` ace. |
| `Config.Distance` | number | `5.0` | How close (in metres) a player must be to a station location for the server to accept opening the menu, starting a craft or finishing one. |
| `Config.Skills` | table | see below | Which skills resource and exports to call. |

### `Config.Skills`

Each value except `resource` is the **name of an export** on `Config.Skills.resource`. Every call is wrapped in `pcall`. If a call fails, a warning is printed once for each export.

| Key | Type | Default | Expected export signature | Used for |
| --- | --- | --- | --- | --- |
| `resource` | string | `'kora_skills'` | - | Resource that provides the exports. |
| `getData` | string | `'GetSkillsData'` | `()` returns a table of `skillName = 'Label'` | Fills the skill list in the creator and checks that a chosen skill exists. Gives the labels shown in the player menu. |
| `getRep` | string | `'getRep'` | `(src, skill)` returns a table with a `level` field | Shows the player's level in the menu (for example "you are level 3"). |
| `isLevel` | string | `'isLevel'` | `(src, skill, level)` returns a boolean | Checks the required level before a craft starts and before it finishes. |
| `addRep` | string | `'addRep'` | `(src, skill, amount)` returns `true`, or `false` and a reason | Gives the recipe's XP after a successful craft. If it refuses, a warning is printed once and the craft still succeeds. |

```lua
Config.Skills = {
    resource = 'kora_skills',
    getData = 'GetSkillsData',
    getRep = 'getRep',
    isLevel = 'isLevel',
    addRep = 'addRep',
}
```

If `getData` does not return a table, the creator shows a free text box for the skill instead of a list. An existing recipe that already has a skill shows that skill as a one-item list. The server then accepts any valid skill name without checking it. While the skill exports are failing, recipes that need a level show as locked ("Skills are unavailable right now") and cannot be crafted.

## `shared/constants.lua`

These are advanced constants. Change them only if you know you need to.

### `ProgressDisableOptions`

The controls that can be disabled while the progress bar runs. They are shown as a multiselect in the creator. The server only accepts these values.

| Value | Label |
| --- | --- |
| `move` | Movement |
| `combat` | Combat |
| `car` | Vehicle (car) |
| `vehicle` | Vehicle (vehicle) |

### Defaults for new recipes

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `DefaultAnim.dict` | string | `'mp_arresting'` | Animation dictionary for a new recipe. |
| `DefaultAnim.clip` | string | `'a_uncuff'` | Animation clip for a new recipe. |
| `DefaultAnim.flag` | number | `49` | Animation flag. It is also used when a saved flag is missing or invalid. |
| `DefaultProgress.time` | number | `5000` | Progress time in ms for a new recipe. It is also used when a stored time is invalid. |
| `DefaultProgress.label` | string | `'Crafting...'` | Progress text. It is also used when a recipe's progress text is empty. |
| `DefaultProgress.disable` | table | `{ move = true, combat = true, car = true }` | Disabled controls for a new recipe. The client also uses it if the server sends none. |

### `Cooldowns`

The time in milliseconds a player must wait between two calls of the same kind. Calls made too soon are refused with "Slow down."

| Key | Default | Description |
| --- | --- | --- |
| `menu` | `1000` | Between two menu opens. The menu that reopens straight after a finished or cancelled craft skips this cooldown once. |
| `begin` | `1000` | Between two craft starts. |

### `LogKeepDays`

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `LogKeepDays` | number | `30` | Rows in `kora_crafting_logs` older than this many days are deleted when the resource starts. |

### `Limits`

| Key | Default | Description |
| --- | --- | --- |
| `recipeItems` | `20` | Maximum number of different materials in one recipe. |
| `recipeAmount` | `1000` | Maximum amount of one material, and maximum amount made. |
| `materialResults` | `24` | Maximum number of item search results the server returns in the creator. The creator shows up to 15 of them. |
| `stationLocations` | `50` | Maximum number of locations on one station. Any extra locations are dropped without a warning. |
| `stationRecipes` | `100` | Maximum number of recipes on one station. |
| `xp` | `100000` | Maximum XP per craft. |
| `level` | `1000` | Maximum required level. |

The creator's form fields have their own limits written into the code: amount 1 to 1000, progress time 500 to 300000 ms, animation flag 0 to 65535, level 0 to 1000 and XP 0 to 100000. If you raise `recipeAmount`, `level` or `xp`, the form still stops at the old values.

## Fixed values in code

These are not configurable but are useful to know:

- Station target boxes are `2 x 2 x 2` with rotation `0` (`client/_functions.lua`).
- New stations get the target label `Craft` and the icon `fa-solid fa-hammer`. Empty values fall back to these.
- A craft must be finished within its progress time plus 15 seconds, and no more than 1 second faster than the progress time.
