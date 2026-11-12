---
title: Troubleshooting
sidebar_position: 13
---

# Troubleshooting

## Job or gang locked locations never open

The server prints:

```text
[kora_crafting] could not read a player's job and gang, so job/gang locked locations stay closed. Fix playerAccess() in server/_functions.lua.
```

`playerAccess()` reads the player with `exports.kora_core:getPlayer(src)`. It looks for `PlayerData`, `playerData` or `data` on the result (or uses the result itself), and expects `job.name` and `gang.name`. If your core stores these in a different way, change that function. Until you do, locked locations refuse everyone, and locations without a lock keep working. The client also hides the target unless `exports.kora_core:getPlayerData()` returns a matching `job.name` or `gang.name`.

## "Crafting is still loading." or "The crafting data is still loading."

The data loads after `kora_sql` is ready. Look in the console for one of these:

- `kora_sql was unavailable; crafting data is not loaded until restart.`: kora_sql was not ready within 60 seconds. Fix kora_sql, then restart kora_crafting.
- `schema failed: ...`: the tables could not be created or updated.
- `could not read the database: ...`: one of the three tables could not be read.

## Skills show as unavailable

Recipes that need a level show "Skills are unavailable right now". For a new recipe the creator shows a text box for the skill instead of a list (a recipe that already has a skill shows that skill as a one-item list). Both mean the exports in `Config.Skills` failed. The console shows a warning such as `the kora_skills export "isLevel" failed: ...`, printed once for each export. Check that the resource is started and that the export names match. See [Configuration](./configuration.md).

## XP is not given

If the `addRep` export refuses the amount, the server prints `kora_skills refused N xp in "skill": reason` once. The craft still succeeds. The skills resource may have its own limit on how much XP one call can give.

## Station targets do not appear

- The client waits up to 30 seconds for `GlobalState.Crafting` and then prints `timed out waiting for GlobalState.Crafting`. This happens if the server never finished loading the data (see above).
- A location with an `object` needs a valid model. The creator checks the model when you place it.
- The recipe must have a result item set, or it is not shown in the menu.

## "Admin permission required."

`/craftCreator` and every creator action need the `command` ace. See [Commands](./commands.md).

## Materials are needed but the craft says "You need ..."

Materials are checked with `exports['qb-inventory']:HasItem`. Make sure `qb-inventory` (or a resource that provides its exports) is running, and that the item names in the recipe match your shared items.
