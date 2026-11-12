---
title: Crafting
sidebar_position: 8
---

# Crafting (player side)

## Station targets

When the client starts, it waits up to 30 seconds for `GlobalState.Crafting` and builds a target for every station location. Each target has one option, with the station's target label and icon. A location is either a `kora_target` box zone or a spawned, frozen prop. The option is hidden while a station menu is open or a craft is running. It is also hidden if the location is locked to a job or gang the player is not in. The client checks this with `exports.kora_core:getPlayerData()`, and the server checks again.

When an admin changes a station, every client rebuilds that station's targets. When the resource stops, all targets and props are removed.

## The menu

Selecting the target asks the server for the station's menu (the `kora_crafting:menu` callback). The server refuses if:

- the crafting data has not finished loading ("Crafting is still loading.")
- the station or location does not exist ("This station is not available.")
- the player is more than `Config.Distance` metres away ("You are too far away.")
- the location is locked to a job or gang the player is not in ("You cannot use this station.")
- the player opened a menu less than 1 second ago ("Slow down.")

The menu opens on the right of the screen (the `kora_crafting:menu` app, 640 x 720), titled with the station name. Recipes are sorted by the name of the item they make and split into two lists:

- **Ready to craft (n)**: the player has every material and meets any level requirement. These cards have a **Craft** button.
- **Missing something (n)**: a material is missing, or the recipe is locked by a skill level. These cards have no button.

Each card shows:

- the item made, with ` | n XP` added if the recipe gives XP
- "Makes `n`x Item" and the item's image
- **Needs**: up to three materials, then "+n more". It is green when everything is there
- **Missing**: the materials the player lacks, in red
- **Skill**: the skill label and the level needed. It is red when the recipe is locked. A locked recipe shows "Needs Skill level N (you are level M)", or "Skills are unavailable right now" if the skills resource cannot be read

A list gets a search box when it has more than 6 cards. If the station has no finished recipes, the menu says "This station has no recipes yet."

## Crafting a recipe

1. Pressing **Craft** closes the menu and calls `kora_crafting:begin`. The server checks the cooldown (1 second), that no other craft is running, the station, distance, lock, that the recipe is on this station and has a result, that the result item exists, the skill level and all materials. If everything passes, it records the craft as pending and sends back the progress settings.
2. The client runs `Kora.progressbar` with the recipe's progress text, time, disabled controls and animation.
3. If the progress bar is cancelled, the client sends `kora_crafting:server:cancel`. Nothing is taken and nothing is given.
4. When the bar finishes, the client calls `kora_crafting:finish`. The server:
   - refuses if more than progress time + 15 seconds have passed ("That took too long. Try again.")
   - refuses and prints a warning if the craft finished more than 1 second faster than the progress time ("You finished too quickly.")
   - checks the station, distance, lock, recipe, skill level and materials again
   - removes the materials that are not marked as kept. If one removal fails, the items already taken are given back
   - adds the result item. If it does not fit, all taken materials are given back ("You do not have room for that.")
   - gives the recipe's XP if it has a skill and an XP value above 0
   - shows the notification "You made `n`x Item."
5. The menu opens again with the player's new stock, so they can craft again. This reopen skips the menu cooldown once. Closing the menu without choosing a recipe ends the loop.

If the player disconnects, any pending craft is dropped.

## Items

kora_crafting does not add any items. Item names and labels come from `exports['qb-core']:GetShared('Items')`, or from `exports.kora_core:getShared('items')` if that is not available. Item images are loaded from `nui://kora_inventory/images/` using the `image` field of each item. The resource checks, takes and gives items with the `qb-inventory` exports `HasItem`, `RemoveItem` and `AddItem`. See [Items](./items.md) for the item source, kept materials and inventory calls.
