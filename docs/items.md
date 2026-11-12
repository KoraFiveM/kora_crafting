---
title: Items
sidebar_position: 6
---

# Items

kora_crafting does not add or define any items. Recipes refer to item names that already exist in your server's shared item list.

## Where item data comes from

The server reads the item list in `server/rules.lua` with `allItems()`:

1. `exports['qb-core']:GetShared('Items')` when that export exists and returns a table.
2. Otherwise `exports.kora_core:getShared('items')`.
3. Otherwise an empty table.

Only names, labels and images are used. The label is shown in the creator and the player menu. If an item has no `image` field, its card has no image. Images are loaded from `nui://kora_inventory/images/` followed by the item's `image` value.

## Inventory calls

Crafting uses these `qb-inventory` exports:

| Export | Used for |
| --- | --- |
| `HasItem(src, item, amount)` | Checks materials before the menu, at craft start and at craft finish |
| `RemoveItem(src, item, amount)` | Takes materials that are not marked as kept |
| `AddItem(src, item, amount)` | Gives the result, and refunds materials when a craft fails |

The resource does not keep an inventory item list of its own. If `qb-inventory` is not running, crafting cannot check or move items.

## What a recipe stores

A recipe stores item names, not item definitions:

- The result item name and amount (1 to 1000).
- Up to 20 different materials. Each material has an item name, an amount (1 to 1000) and an optional `keep` flag.
- Item names are at most 64 characters and may contain letters, numbers, `_`, `-` and `.`.

When you add a new material in the creator, the server checks that the item exists in the shared item list. A material that was already saved can still be saved if it has since been removed from the shared list; its card in the creator says it is not in the shared items.

## Kept materials

Mark a material as **No, the player keeps it** (the stored `keep` flag) when it is a tool or another item that must be in the inventory but is not used up. The server still checks that the player has the amount, but `RemoveItem` is not called for that material.

## No items file

There is no items file or SQL import in kora_crafting. Add items in your inventory or core resource and make sure their names match the names used in recipes. If you change an item name later, edit the recipes that use it in the [Crafting Creator](./creator.md).

See [Crafting](./crafting.md) for the player-side item checks and [Configuration](./configuration.md) for the item-related limits.
