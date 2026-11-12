---
title: Exports
sidebar_position: 10
---

# Exports

kora_crafting has **no public server or client exports** for normal use. Recipes and stations are managed through the [Crafting Creator](./creator.md); the only exports are the development-only FFT hooks below. Other resources can read the public station list from the `GlobalState.Crafting` state bag (see [Events and callbacks](./events.md#state-bag)).

## Development-only FFT hooks (client)

`fft_hooks.lua` is loaded last on the client. It does nothing unless the replicated convar `fft_kora_hooks` is `true`:

```cfg
setr fft_kora_hooks true
```

When the convar is set, it registers two client exports for the FFT test runner. They are not meant for normal resources. Do not enable them on a live server.

### `fftVersion()`

Returns the hook version number (`1`).

```lua
local version = exports.kora_crafting:fftVersion()
```

### `fftAction(action, ...)`

Runs a test action. The export only answers when the calling resource is `fft`, `fft` is started, and the player has a string `LocalPlayer.state.fftSession`. Otherwise it returns `false` and an error message.

| Action | Arguments | Returns |
| --- | --- | --- |
| `state` | none | A table with `crafting` (whether a menu or craft is running) and `stations`; each station has `id`, `targetLabel` and `locations` (the number of locations) |
| `registry` | none | A table with `recipes` and `stations` (the ids of the `fft_` entries on the server) and `skills` (the number of registered skills) |
| `purge` | none | `true` and the number of `fft_` stations and recipes deleted |
| `fixture` | a table with `makes`, `amount`, `give`, `job` and `skillLocked` | Deletes the old test data, creates an `FFT recipe` and an `FFT station` with one location 1.6 m in front of the player, and returns the recipe id, station id, target label and aim point |

### `fixture` spec

| Key | Type | Rules |
| --- | --- | --- |
| `makes` | string | Required. Item name, up to 64 characters using the same characters as a recipe item |
| `amount` | integer | Optional, default `1`, from `1` to `10` |
| `give` | table | Optional, up to 5 entries. Each entry has `item` (item name) and `amount` (`1` to `50`), plus an optional `keep` boolean |
| `job` | string | Optional. Letters, numbers, `_` and `-`, up to 32 characters |
| `skillLocked` | boolean | When `true`, uses the first registered skill and level `1000` |

The fixture validates `makes`, `amount`, `give` and `job` first, and refuses while the player is in a vehicle. If an admin callback is refused, the third return value is `rejected`; invalid input and a missing skill return `invalid` and `blocked`. On success it returns a table with `recipe`, `station`, `targetLabel` and `aim` (the `x`, `y` and `z` of the point to aim at).

The hooks use the same admin callbacks as the creator. The server still checks the `command` ace, validates the data and writes the audit log. The hooks only change recipes and stations whose id starts with `fft_`.
