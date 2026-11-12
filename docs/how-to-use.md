---
title: "How to use"
sidebar_position: 3
---


# How to use

A recipe describes one craftable item (what it needs, what it gives, the animation and progress bar, an optional skill gate). A station is a named target point (or several placed locations) that offers a chosen set of recipes. Admins build both from an in-game creator; players craft from the station's own menu.

## Opening the creator

The creator is a single chat/console command, configurable in `shared/config.lua` (`Config.Command = 'craftCreator'`). Running it checks `IsPlayerAceAllowed(src, 'command')` on the server. Without the ACE, the player is notified and the command does nothing; the console additionally logs who was denied. On success the server fires the client event `kora_crafting:creator:open`, which opens the "Crafting Creator" AppShell app (1200x800, standard layout).

```lua title="server/creator.lua"
-- Server: the one command this resource registers (name from Config.Command)
RegisterCommand(Config.Command, function(source)
    if not isAdmin(source) then
        Kora.notify.send(source, { title = 'Crafting Creator', message = 'Admin permission required.', type = 'error' })
        return
    end
    TriggerClientEvent('kora_crafting:creator:open', source)
end, false)
```

- The client event handler itself also checks `source ~= 65535` before opening anything, so the open only ever reacts to a server-triggered event, not a locally fired one.

## Building a recipe

- `newRecipe(label)` starts a recipe with a default animation (`mp_arresting` / `a_uncuff`, flag 49) and default progress (5000 ms, "Crafting...", movement/combat/car disabled). Nothing is craftable until it has a `receive` item.
- Required items (`give`) are added by searching the item catalog; each entry has an item, an amount (1 to `Limits.recipeAmount`, default 1000) and an optional `keep` flag so the material is checked but not consumed.
- Progress time must be 500-300000 ms; the disable flags come from `ProgressDisableOptions` (`move`, `combat`, `car`, `vehicle`) in `shared/constants.lua`.
- An optional skill, level and xp: if `Config.Skills` resolves a skill list, the creator shows a dropdown; otherwise it falls back to a free-text box. A `level` above 0 blocks players under that level; `xp` (if above 0) is awarded on a successful craft.
- Recipes are limited to `Limits.recipeItems` (20) materials each, and a server has at most `Limits.stationRecipes` (100) recipes per station and `Limits.stationLocations` (50) locations per station.

## Building a station and placing it in the world

A station has a label, a target prompt (`targetLabel`, `targetIcon`), the list of recipe ids it offers, and any number of placed locations.

```lua title="client/creator.lua"
-- Client: placing a station location (simplified from client/creator.lua)
-- "station:place" starts a loop that saves a new location on every selection
-- until the admin presses the raycast tool's own cancel key.
local aimed = Kora.raycast.getCoords(tool.object and { type = 'object', object = tool.object } or {})
local c = aimed and aimed.coords
local place = { coords = { x = c.x, y = c.y, z = c.z, w = c.w or aimed.heading }, object = tool.object, gang = tool.gang, job = tool.job }
Kora.callback.trigger('kora_crafting:creator:stations:locations', station.id, appended(station.locations, place))
```

- A location is placed by aim: the creator opens a raycast placement loop (optionally locked to an object model instead of a bare point) and saves a new location each time you confirm, until you cancel the tool.
- A location may carry a `gang` and/or `job` restriction. When either is set, a player needs to match the gang OR the job to use that specific location (see "Access checks" below); other locations of the same station are unaffected.
- Setting `object` on a location spawns that prop at the saved coordinates (frozen, invincible) and targets the prop itself instead of a bare box zone.

## What the player sees and does

1. **Zones are built from replicated state** — The client waits for `GlobalState.Crafting` (up to 30 s) and builds one target registration per station location: a box zone for a bare point, or a targetable prop for an `object` location. A live edit in the creator replays `kora_crafting:client:stationReload` to rebuild just that station.

2. **Aim and select** — Aiming at the location (through kora_target) offers the station's `targetLabel`/`targetIcon`. The option is hidden client-side while a craft/menu is already open, or while the gang/job lock (checked against the player's own job/gang) fails — a convenience check only; the server re-checks.

3. **The recipe menu** — Selecting the option opens the "Crafting" AppShell app, split into "Ready to craft" and "Missing something" cards. Each card shows what it makes, the needed materials (with a destructive "Missing" line for anything you lack), the skill/level if any, and bonus XP in the title.

4. **Craft it** — Picking "Craft" starts the server-returned progress bar (with the recipe's animation and disable flags) through `Kora.progressbar.start`. Cancelling the bar fires `kora_crafting:server:cancel`. Finishing calls back to the server, which re-validates everything and gives the result.

## Server-side revalidation (the client is never trusted)

Both `kora_crafting:begin` and `kora_crafting:finish` run the same `resolveStation` / `craftable` checks used to build the menu, so a modified client gains nothing:

- Distance: the player must be within `Config.Distance` (5.0 m) of the location's coordinates (`Kora.distance.player`).
- Access: `locationAllowed` re-checks the gang/job lock using `exports.kora_core:getPlayer(src)`, never the client's claim.
- Recipe validity: the recipe must still be attached to that station and have a `receive` item that exists in the shared item catalog.
- Skill level: if the recipe needs a level, `exports.kora_skills:isLevel(src, skill, level)` (or your configured resource/export) is checked again on the server.
- Materials: `exports['qb-inventory']:HasItem` is checked again right before taking the items.
- Timing: `kora_crafting:begin` stamps an expiry (`progress.time + 15000` ms); `kora_crafting:finish` rejects a result that arrives too late, or more than 1000 ms early (logging a warning), closing the "run finish without waiting" exploit.
- Rollback: if taking a material fails partway through, every material already removed is returned; if the crafted item cannot fit, every removed material is given back instead of being lost.

## Rate limits and logging

- `Config.Cooldowns`-style timers (`Cooldowns.menu` and `Cooldowns.begin`, both 1000 ms in `shared/constants.lua`) stop a player from spamming the menu-open or begin-craft callbacks faster than once a second each.
- Every creator action that changes data (not the two read-only `get` / `items:search` calls) is written to `kora_crafting_logs` with the admin's source, name, license identifier, the callback name as `action`, and a small JSON `details` blob (currently just the affected id). Rows older than `LogKeepDays` (30) are purged once at boot.
- Console command `craftLogs` (server console only) prints the most recent log rows.

## More detail

- [Crafting Creator](./creator.md): every field of the recipe and station editors.
- [Crafting](./crafting.md): the player menu and the server checks for each craft.
- [Configuration](./configuration.md): `shared/config.lua` and `shared/constants.lua`.
- [Events and callbacks](./events.md) and [Database](./database.md): the callbacks used above and the stored data.
