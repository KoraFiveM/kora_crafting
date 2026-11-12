---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Crafting is a crafting-station engine with an in-game creator: an admin builds recipes, stations and placed locations from a menu, and players craft at those locations. It declares `dependency 'kora_lib'`, `dependency 'kora_core'` and `dependency 'kora_sql'`.

## Install Kora Crafting

1. **Add the folder** — Place `kora_crafting` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_crafting`). Keep the folder name unchanged: it is also the export name consumers use (`exports.kora_crafting`, if any).

2. **Start order** — The README asks for `ensure kora_crafting` after `kora_sql`, `kora_lib`, `kora_core`, an inventory that answers to the `qb-inventory` export name, `kora_target`, and whatever skills resource `Config.Skills.resource` names.

   ```bash title="server.cfg"
   ensure kora_sql
   ensure kora_lib
   ensure kora_core
   ensure kora_inventory   # or anything answering exports["qb-inventory"]
   ensure kora_target
   ensure kora_skills      # or your Config.Skills.resource
   ensure kora_crafting
   ```

3. **`@kora_sql/init.lua` loads on the server only** — This resource's manifest lists `@kora_sql/init.lua` as the first entry of `server_scripts`, not as a shared script. `Kora.sql.*` is therefore only available to the server files (`server/schema.lua` onward); no client file in this resource touches the database.

   ```lua title="fxmanifest.lua" {20}
   dependency 'kora_lib'
   dependency 'kora_core'
   dependency 'kora_sql'

   shared_scripts {
       '@kora_lib/init.lua',
       '@kora_core/init.lua',
       'shared/constants.lua',
       'shared/config.lua',
   }

   client_scripts {
       'client/_functions.lua',
       'client/craft.lua',
       'client/creator.lua',
   }

   -- Order matters here: each file uses the ones before it.
   server_scripts {
       '@kora_sql/init.lua',
       'server/schema.lua',
       'server/_functions.lua',
       'server/skills.lua',
       'server/rules.lua',
       'server/data.lua',
       'server/creator.lua',
       'server/craft.lua',
       'server/logs.lua',
   }
   ```

4. **Tables are created automatically** — On start the server waits for `Kora.sql.ready()` and runs `Kora.sql.ensureTables` against its own schema (`kora_crafting_recipes`, `kora_crafting_stations`, `kora_crafting_logs`). There is no SQL file to import.

5. **Grant creator access** — The creator command and every admin callback check `IsPlayerAceAllowed(src, 'command')` (the same ACE `/drugCreator` uses in the Kora stack). Give trusted staff that ACE, for example `add_ace group.admin command allow`.

## Soft (undeclared) dependencies

- kora_target: every station location is registered with `exports.kora_target:addBoxZone` or `exports.kora_target:addEntity`. The manifest does not list `dependency 'kora_target'`, so start it yourself before `kora_crafting` or the target calls fail.
- An inventory answering `exports['qb-inventory']`: `HasItem`, `RemoveItem` and `AddItem` are called directly under that export name in `server/craft.lua`. kora_inventory's qb-inventory compatibility layer satisfies this; a different inventory must expose the same three calls.
- Items: the item catalog is read with `exports['qb-core']:GetShared('Items')` first, falling back to `exports.kora_core:getShared('items')`. Either needs to return a table keyed by item name with at least a `label` (and optionally `image`).
- A skills resource matching `Config.Skills` (default `kora_skills`) for recipes that gate on a skill level or award XP. Without it, skill-gated recipes still work but always report skills as unavailable (see Configuration).

## If it does not start or nothing can be crafted

- Console warns `kora_sql was unavailable; crafting data is not loaded until restart`: kora_sql did not become ready within 60 seconds of this resource starting. Fix kora_sql and restart kora_crafting.
- Console warns `schema failed: ...`: `Kora.sql.ensureTables` could not create or alter the three tables; check the database user's privileges.
- Console warns about `playerAccess`: `exports.kora_core:getPlayer(src)` did not return a table with a `job` or `gang` field. Job/gang-locked locations stay closed for everyone until `playerAccess()` in `server/_functions.lua` is adjusted for your player object shape.
- No target option appears at a placed location: confirm `kora_target` is running and that `GlobalState.Crafting` populated (the client waits up to 30 seconds for it, then warns and gives up).

## Dependency summary

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

## Further notes

- The manifest also loads `fft_hooks.lua` last in `client_scripts`. It does nothing unless the replicated convar `fft_kora_hooks` is `true`; see [Exports](./exports.md).
- No items are added by this resource. Recipes can use any item in the shared item list. See [Items](./items.md).
- If your core stores jobs and gangs differently, check `playerAccess()` in `server/_functions.lua`. See [Troubleshooting](./troubleshooting.md).
- After installing, run `/craftCreator`, create recipes first, then a station, add the recipes and place its locations. See [Crafting Creator](./creator.md).
