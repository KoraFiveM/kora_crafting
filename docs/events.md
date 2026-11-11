---
title: Events and callbacks
sidebar_position: 8
---

# Events and callbacks

All of the net events and callbacks below are **internal**. They are documented so you know how the resource works. Do not trigger them from other resources. Every server callback checks its input and permissions, and calls that fail those checks are refused.

## State bag

### `GlobalState.Crafting`

Set by the server when the data has loaded and after every station change. It holds only what clients need to build the targets. This state bag never contains recipes.

```lua
GlobalState.Crafting = {
    stations = {
        [stationId] = {
            id = 'workbench',
            label = 'Workbench',
            targetLabel = 'Craft',
            targetIcon = 'fa-solid fa-hammer',
            locations = {
                { coords = { x = 0.0, y = 0.0, z = 0.0, w = 90.0 }, object = 'prop_toolchest_01', gang = nil, job = 'mechanic' },
            },
        },
    },
}
```

Other resources may read this state bag, for example to show station blips.

## Net events

| Event | Direction | Payload | Notes |
| --- | --- | --- | --- |
| `kora_crafting:client:stationReload` | server to all clients | `stationId`, `entry` (the public station shown above, or `nil` if it was deleted) | Sent after a station is saved or deleted. Clients rebuild that station's targets. Other client resources can listen to it. |
| `kora_crafting:creator:open` | server to one client | none | Opens the creator. The client only accepts it from the server (source `65535`). Internal. |
| `kora_crafting:server:cancel` | client to server | none | Sent when the player cancels the progress bar. It clears the pending craft. Internal. |

## Callbacks (`Kora.callback`)

### Player callbacks

| Name | Arguments | Returns |
| --- | --- | --- |
| `kora_crafting:menu` | `stationId`, `locationIndex` | `label` and `recipes` (the menu cards), or `false` and an error message |
| `kora_crafting:begin` | `stationId`, `locationIndex`, `recipeId` | `time`, `label`, `disable` and `anim`, or `false` and an error message |
| `kora_crafting:finish` | none | `true`, or `false` and an error message |

See [Crafting](./crafting.md) for the checks each one makes.

### Admin callbacks (creator)

All of these need the `command` ace. They return `The crafting data is still loading. Try again in a moment.` until the data has loaded. Each returns the full creator data on success (the create and duplicate callbacks also return the new `id`), or `false` and an error message. Every one except `creator:get` and `creator:items:search` is written to `kora_crafting_logs`.

| Name | Arguments |
| --- | --- |
| `kora_crafting:creator:get` | none |
| `kora_crafting:creator:items:search` | `query`, `recipeId` |
| `kora_crafting:creator:recipes:create` | `label` |
| `kora_crafting:creator:recipes:duplicate` | `recipeId` |
| `kora_crafting:creator:recipes:details` | `recipeId`, a table with `label`, `tag`, `amount`, `progress`, `anim`, `skill`, `xp` and `level` |
| `kora_crafting:creator:recipes:item` | `recipeId`, `itemName` |
| `kora_crafting:creator:recipes:give` | `recipeId`, a list of tables with `item`, `amount` and `keep` |
| `kora_crafting:creator:recipes:delete` | `recipeId` |
| `kora_crafting:creator:stations:create` | `label` |
| `kora_crafting:creator:stations:duplicate` | `stationId` |
| `kora_crafting:creator:stations:details` | `stationId`, a table with `label`, `targetLabel` and `targetIcon` |
| `kora_crafting:creator:stations:recipes` | `stationId`, a list of recipe ids |
| `kora_crafting:creator:stations:locations` | `stationId`, a list of tables with `coords`, `object`, `gang` and `job` (this replaces the whole list) |
| `kora_crafting:creator:stations:delete` | `stationId` |

## NUI apps

| App id | Description |
| --- | --- |
| `kora_crafting:menu` | The player station menu |
| `kora_crafting:creator` | The admin creator |
