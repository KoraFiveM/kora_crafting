> [!WARNING]
> **Kora Framework is in alpha and actively being developed.**
>
> This resource is a work in progress. Features may be incomplete or unstable,
> and APIs, configuration, and behavior may change. It is not ready for production use.
>
> **Help shape Kora:** try it out, share feedback, report bugs through this
> repository’s Issues, and contribute improvements through pull requests.

# kora_crafting

Crafting stations and recipes, built and edited in game. The creator works like the kora_drugs creator.

## Install

1. `ensure kora_crafting` after `kora_sql`, `kora_lib`, `kora_core`, `qb-inventory`, `kora_target` and your skills resource.
2. The three tables (`kora_crafting_recipes`, `kora_crafting_stations`, `kora_crafting_logs`) are created and kept up to date automatically on start by kora_sql; there is no SQL file to import.
3. Give admins the `command` ace (the same one `/drugCreator` uses), then run `/craftCreator`.

## Creator

**Recipes**: a grid of recipes and a *Create new recipe* button. A recipe has:

- Name, the item it makes (a grid you can search, then *Select*) and the amount made
- Required items (search, *Add*, edit the amount, or mark an item as kept instead of used up)
- Progress text and time, the animation (dictionary, clip, flag) and what is disabled while crafting
- Optional skill (from `exports.kora_skills:GetSkillsData()`), the level needed and the xp given

**Stations**: a grid of stations and a *Create new station* button. A station has:

- A name, the target label and the target icon
- The recipes players can craft there (add and remove them from the grid)
- Any number of locations, each placed by aiming. A location can be locked to a **gang**, a **job**
  (a member of either is let in when both are set) or use an **object**: a prop that is spawned there
  and used as the target instead of a plain zone.

## Players

Using a station opens its recipes as cards: what it makes, what it needs, the skill and level, the xp.
The server checks everything again when the craft starts and when the bar ends (distance, lock, recipe on
the station, level, materials), so a modified client gets nothing. If the player has no room for the
result, the materials are given back.

## Things to check against your server

- `Config.Skills` in `shared/config.lua`: the kora_skills exports this script calls. `isLevel` checks the level,
  `addRep` gives the xp (kora_skills refuses an amount above its `Config.maxAward`), `getRep` shows the player's
  level in the menu, and `GetSkillsData` (`{ skillName = 'Label' }`) fills the skill list in the creator.
  Without `GetSkillsData` the creator shows a text box for the skill instead of a list.
- `playerAccess()` in `server/_functions.lua` reads a player's job and gang on the server
  (`exports.kora_core:getPlayer(src)`). If your core is different, change that one function. Until it
  works, job and gang locked locations stay closed and a warning is printed.

Full documentation: see [docs/](docs/index.md).
