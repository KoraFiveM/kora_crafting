---
title: Database
sidebar_position: 9
---

# Database

The tables are defined in `server/schema.lua` (`KoraCraftingSchema`). About one second after the resource starts, it waits up to 60 seconds for `kora_sql` and then creates or updates the tables with `Kora.sql.ensureTables`. There is no `.sql` file to import. Any schema warnings are printed to the console.

Once the tables are ready, the server deletes old log rows and loads every recipe and station into memory. Until then, the menu and creator refuse to work and say the data is still loading.

## `kora_crafting_recipes`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `varchar(48)` | Primary key. Recipe id (letters, numbers and `_`) |
| `data` | `longtext` | JSON recipe |

```json
{
  "label": "Iron Bar",
  "receive": { "item": "iron_bar", "amount": 1 },
  "give": [
    { "item": "iron_ore", "amount": 3 },
    { "item": "hammer", "amount": 1, "keep": true }
  ],
  "anim": { "dict": "mp_arresting", "clip": "a_uncuff", "flag": 49 },
  "progress": { "time": 5000, "label": "Crafting...", "disable": { "move": true, "combat": true, "car": true } },
  "tag": "metal",
  "skill": "crafting",
  "xp": 10,
  "level": 2
}
```

`receive`, `tag`, `skill`, `xp` and `level` are optional. When a row is loaded, every field is checked and cleaned. Bad values are replaced with the defaults, and any materials beyond the limit are dropped.

## `kora_crafting_stations`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `varchar(48)` | Primary key. Station id |
| `data` | `longtext` | JSON settings |
| `locations` | `longtext` | JSON list of locations |

```json
{ "label": "Workbench", "targetLabel": "Craft", "targetIcon": "fa-solid fa-hammer", "recipes": ["iron_bar"] }
```

```json
[
  { "coords": { "x": 100.0, "y": -200.0, "z": 30.0, "w": 90.0 }, "object": "prop_toolchest_01", "job": "mechanic" }
]
```

`object`, `gang` and `job` are optional on each location. `w` is the heading.

## `kora_crafting_logs`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `int` auto increment | Primary key |
| `created_at` | `timestamp` | Default `CURRENT_TIMESTAMP`. Indexed |
| `source` | `int` | Server id of the player |
| `name` | `varchar(64)` | Player name |
| `identifier` | `varchar(64)` | License identifier |
| `action` | `varchar(64)` | Creator callback name |
| `details` | `text` | JSON, for example `{"id":"iron_bar"}` |

Only changes made in the creator are logged. Rows older than `LogKeepDays` (30) days are deleted when the resource starts. Read the log with [`craftLogs`](./commands.md#craftlogs).
