# qbcrafting

Crafting stations and recipes, built and edited in game. The creator works like the qbdrugs creator.

## Install

1. `ensure qbcrafting` after `qbsql`, `qblib`, `qbcore`, `qb-inventory`, `qbtarget` and your skills resource.
2. The two tables are created on start. `sql/qbcrafting.sql` has the same statements if you prefer to run them yourself.
3. Give admins the `command` ace (the same one `/drugCreator` uses), then run `/craftCreator`.

## Creator

**Recipes**: a grid of recipes and a *Create new recipe* button. A recipe has:

- Name, the item it makes (a grid you can search, then *Select*) and the amount made
- Required items (search, *Add*, edit the amount, or mark an item as kept instead of used up)
- Progress text and time, the animation (dictionary, clip, flag) and what is disabled while crafting
- Optional skill (from `exports.qbskills:GetSkillsData()`), the level needed and the xp given

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

- `Config.Skills` in `shared/config.lua`: the qbskills exports this script calls. `isLevel` checks the level,
  `addRep` gives the xp (qbskills refuses an amount above its `Config.maxAward`), `getRep` shows the player's
  level in the menu, and `GetSkillsData` (`{ skillName = 'Label' }`) fills the skill list in the creator.
  Without `GetSkillsData` the creator shows a text box for the skill instead of a list.
- `playerAccess()` in `server/_functions.lua` reads a player's job and gang on the server
  (`exports.qbcore:getPlayer(src)`). If your core is different, change that one function. Until it
  works, job and gang locked locations stay closed and a warning is printed.
