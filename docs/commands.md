---
title: "Commands"
sidebar_position: 4
---


# Commands

Kora Crafting registers two commands. There is no in-game command for players; crafting is entirely target-driven.

## Built-in commands

### `/craftCreator`

Opens the Crafting Creator app for the calling player. Checked against the `command` ACE on the server before the client event is fired.

| Field | Details |
| --- | --- |
| Context | In-game · server command (name from `Config.Command`) |
| Arguments | No arguments. |
| Access | A player with the `command` ACE (`IsPlayerAceAllowed(src, 'command')`). The server console cannot use it (`isAdmin` requires a source above 0). Anyone else is notified "Admin permission required." and the denial is logged to console. |

**Example**

```text
/craftCreator
```

**Result**

Opens the "Crafting Creator" AppShell app for recipes, stations and placing locations.

### `craftLogs [n]`

Prints the `n` most recent rows of `kora_crafting_logs` (every admin change, newest first) to the server console.

| Field | Details |
| --- | --- |
| Context | Server console only · server command |
| Arguments | n? — number of rows, clamped to 1-200. Defaults to 20 when omitted or not a number. |
| Access | Server console only (`source == 0`). Running it from a player connection prints a debug line and does nothing. |

**Example**

```text
craftLogs
craftLogs 100
```

**Result**

One line per row: `[timestamp] #id name (identifier) action details`, or "no logs yet." when the table is empty.

## Additional details

The server prints a warning when a player is denied `/craftCreator`. Every creator callback checks the same `command` ace again on the server, so the ace is the only permission needed. The command is registered unrestricted, so anyone can type it, but only players with the ace get the creator.

```cfg title="server.cfg"
add_ace group.admin command allow
```

For `craftLogs`, `action` is the name of the creator callback, for example `kora_crafting:creator:recipes:give`, and `details` is JSON such as `{"id":"iron_bar"}`. Only changes made in the creator are logged. Crafts and the read-only creator calls (`creator:get` and `creator:items:search`) are not logged. See [Database](./database.md).

The command prints with `Kora.print.debug`. If your `kora_lib` hides debug output, you may not see anything.

The creator itself is described in [Crafting Creator](./creator.md).
