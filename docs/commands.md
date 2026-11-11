---
title: Commands
sidebar_position: 3
---

# Commands

kora_crafting has no key mappings.

## `/craftCreator`

| | |
| --- | --- |
| Name | The value of `Config.Command` (default `craftCreator`) |
| Arguments | none |
| Side | Server (`RegisterCommand`, not restricted) |
| Permission | The player needs the `command` ace (`IsPlayerAceAllowed(src, 'command')`) |
| Effect | Opens the [Crafting Creator](./creator.md) on the player's client |

Anyone can type the command, but the server checks the `command` ace first. Players without it get a "Crafting Creator: Admin permission required." notification, and the server prints a warning. Every creator callback checks the same ace again on the server. The command does not work from the server console because the console is not a player.

```cfg
add_ace group.admin command allow
```

## `craftLogs`

| | |
| --- | --- |
| Name | `craftLogs` |
| Arguments | `[count]`: how many rows to show. Default `20`, range 1 to 200 |
| Side | Server console only (registered as restricted, and refuses any source other than `0`) |
| Effect | Prints the newest rows of `kora_crafting_logs`, newest first |

Each row is printed as:

```text
[created_at] #id name (license) action details
```

`action` is the name of the creator callback, for example `kora_crafting:creator:recipes:give`. `details` is JSON such as `{"id":"iron_bar"}`. Only changes made in the creator are logged. Crafts and the read-only creator calls (`creator:get` and `creator:items:search`) are not logged. See [Database](./database.md).

The command prints with `Kora.print.debug`. If your `kora_lib` hides debug output, you may not see anything.

```bash
craftLogs 50
```
