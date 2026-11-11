---
title: kora_crafting
sidebar_position: 1
---

# kora_crafting

kora_crafting adds crafting stations and recipes that admins build and edit in game. There is no config file of recipes or stations. An admin opens the **Crafting Creator** (`/craftCreator`), creates recipes (what is made, what it costs, progress bar, animation, optional skill requirement and XP), then creates stations, puts recipes on them and places locations by aiming. Recipes and stations are saved to the database; station changes are published to every client right away. Players use a station through `kora_target`. The server checks every craft again, so a modified client cannot craft for free.

## Features

- **In-game creator**: a Kora NUI app with Recipes and Stations pages. Admins create, edit, duplicate and delete recipes and stations without restarting. See [Crafting Creator](./creator.md).
- **Recipes**: each recipe has a result item and amount, up to 20 required items (each one can be marked as *kept* so it is needed but not used up), progress text and time, an animation, the controls disabled while crafting, and an optional search tag.
- **Skill integration**: a recipe can name a skill from your skills resource (`kora_skills` by default), require a level in it and give XP for each craft. Players below the level see the recipe as locked.
- **Stations**: a station has a name, a target label and icon, a list of recipes and up to 50 locations. Each location can be a plain 2 x 2 x 2 target box or a spawned, frozen prop. It can also be locked to a job, a gang, or both (a member of either may use it).
- **Live updates**: saving a station rebuilds its targets on every client at once. Players who join later get the current stations through `GlobalState.Crafting`.
- **Player menu**: using a station opens a compact menu of recipe cards, split into *Ready to craft* and *Missing something*. Cards show the product, the materials (missing ones in red), the skill and level, and the XP. After a craft the menu opens again with your updated stock. See [Crafting](./crafting.md).
- **Server checks**: distance, location lock, recipe on that station, skill level and materials are checked when the craft starts and again when it finishes. Craft time and inventory space are checked when it finishes. If the result does not fit, the materials are returned.
- **Audit log**: every change made in the creator is written to `kora_crafting_logs`. You can read the log from the server console with `craftLogs`. Rows older than 30 days are removed when the resource starts.

## Requirements

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| `kora_lib` | `Kora.callback`, `Kora.nui`, `Kora.notify`, `Kora.progressbar`, `Kora.raycast`, `Kora.entities`, `Kora.state`, `Kora.distance`, `Kora.print` |
| `kora_core` | Player job and gang (`getPlayer` on the server, `getPlayerData` on the client). Shared items through `getShared('items')` if `qb-core` is missing |
| `kora_sql` | Table creation (`Kora.sql.ensureTables`) and all queries |

Used at runtime but not declared as dependencies:

| Resource | Used for |
| --- | --- |
| `qb-inventory` | `HasItem`, `RemoveItem`, `AddItem` exports (required for crafting) |
| `qb-core` | `GetShared('Items')` export, tried first for the item list |
| `kora_target` | `addBoxZone`, `addEntity`, `removeZone` exports for station targets (required) |
| `kora_inventory` | Item images are loaded from `nui://kora_inventory/images/` |
| `kora_skills` | Optional. The skill exports set in `Config.Skills` (see [Configuration](./configuration.md)) |

## Installation

1. Put the resource in your resources folder and start it after its dependencies:

   ```cfg
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure qb-inventory
   ensure kora_target
   ensure kora_skills
   ensure kora_crafting
   ```

   `kora_skills` is optional; leave it out when you do not use skill requirements.

2. You do not need to import any SQL. On start, `kora_sql` creates `kora_crafting_recipes`, `kora_crafting_stations` and `kora_crafting_logs` and keeps them up to date. See [Database](./database.md).
3. The resource does not add any items of its own. Recipes can use any item in the shared item list.
4. Give admins the `command` ace (for example `add_ace group.admin command allow`). This one ace allows `/craftCreator` and every creator action.
5. In game, run `/craftCreator`. Create recipes first, then create a station, add the recipes and place its locations.
6. If your core stores jobs and gangs in a different way, check `playerAccess()` in `server/_functions.lua`. See [Troubleshooting](./troubleshooting.md).

## Pages

- [Configuration](./configuration.md): `shared/config.lua` and the constants in `shared/constants.lua`
- [Commands](./commands.md): `/craftCreator` and `craftLogs`
- [Crafting Creator](./creator.md): building recipes and stations in game
- [Crafting](./crafting.md): what players see and how the server checks each craft
- [Items](./items.md): item sources, images, kept materials and inventory calls
- [Exports](./exports.md): public exports (there are none, apart from the dev-only FFT hooks)
- [Events and callbacks](./events.md): net events, callbacks and the state bag
- [Database](./database.md): tables and stored JSON
- [Troubleshooting](./troubleshooting.md)
