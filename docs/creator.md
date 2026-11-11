---
title: Crafting Creator
sidebar_position: 4
---

# Crafting Creator

The creator is a Kora NUI app (`kora_crafting:creator`, standard layout, 1200 x 800). Open it with [`/craftCreator`](./commands.md). It needs the `command` ace. When it opens, the client asks the server for the full list of recipes and stations, and the server checks the ace on every action. A change is saved straight to the database. Station changes reach every client at once.

The app has four pages: **Recipes**, **Recipe** (once you pick one), **Stations**, and **Station** (once you pick one).

## IDs

When you create a recipe or station you only type a name. The id is made from that name: it is lowercased, every run of characters that are not letters or numbers becomes `_`, leading and trailing `_` are removed, and it is cut to 36 characters. A name with no letters or numbers becomes `new`. If the id is taken, `_2`, `_3` and so on is added. For example, "Iron Bar" becomes `iron_bar`. The id never changes after it is created, even if you rename the recipe or station.

Names can be up to 48 characters long.

## Recipes

The **Recipes** page shows every recipe as a card with its name, what it makes, what it needs, its skill and level, and its tag. A recipe that has no result item yet is marked *Not finished: pick the item it makes*. **Create new recipe** asks for a name and opens the new recipe.

A new recipe starts with no result, no materials, the default animation (`mp_arresting` / `a_uncuff`, flag 49) and the default progress settings (5000 ms, "Crafting...", movement, combat and car disabled). See [Configuration](./configuration.md#defaults-for-new-recipes).

### Details form

| Field | Rules |
| --- | --- |
| Recipe name | Required, up to 48 characters |
| Tag | Optional, up to 32 characters. Players never see it. It is used in the creator's recipe search |
| Amount made | 1 to 1000. Only shown once a result item is set |
| Progress text | Optional, up to 64 characters. When empty, the default (`Crafting...`) is used |
| Progress time (ms) | 500 to 300000 |
| Animation dictionary | Letters, numbers and `_ @ - .`, up to 64 characters. The client checks that the dictionary exists. Leave the dictionary and the clip empty for no animation |
| Animation clip | Same rules. The dictionary and clip must both be set or both be empty |
| Animation flag | 0 to 65535 |
| Disable while crafting | Any of `move`, `combat`, `car`, `vehicle` |
| Skill | A list from the skills resource (with a *No skill* option), or a text box if the skills resource cannot be read. When the list is available, the server rejects skills that are not on it |
| Level required | Optional, 0 to 1000. Only used when a skill is set. Empty or 0 means no level is needed |
| XP given | Optional, 0 to 100000. Given in the recipe's skill after each successful craft |

### Result item and materials

Use **Find items** to search all shared items by name or label. The server returns up to 24 matches and the creator shows up to 15. Each result card has these buttons:

- **Set as result**: the recipe now makes this item. The amount made is kept, or set to 1 for a new recipe. The item must exist in the shared items.
- **Add to recipe**: asks for the amount needed (1 to 1000) and whether it is used up. Choose *No, the player keeps it* for tools that must be in the inventory but are not taken.

Each card under **Required items** has an **Edit** button (change the amount or the kept setting) and a **Remove** button. A recipe can have at most 20 different materials, and an item can only be in the list once. If a material is no longer in the shared items, its card says so. You can still save the recipe with that item.

A recipe without a result item is never shown to players, even if it is on a station.

### Duplicate and delete

- **Duplicate recipe** copies everything into a new recipe named `Name-2` (or the next free number) and opens the copy.
- **Delete recipe** asks you to confirm, then deletes the recipe and **removes it from every station** that had it.

## Stations

The **Stations** page lists every station with its number of recipes and locations. **Create new station** asks for a name and opens the new station. New stations get the target label `Craft` and the icon `fa-solid fa-hammer`.

### Settings

| Field | Rules |
| --- | --- |
| Station name | Required, up to 48 characters. Shown as the title of the player menu |
| Target label | Up to 48 characters. Empty means `Craft` |
| Target icon | Up to 64 characters, a Font Awesome class. Empty means `fa-solid fa-hammer` |

### Recipes on the station

**Recipes on this station** lists the recipes players can craft here. Each one has a **Remove** button. **Find a recipe to add** searches the name, the tag, the result item name and its label. If you type several words, all of them must match. An empty search shows every recipe that is not on the station yet. A station can have up to 100 recipes.

### Locations

Fill in the **Place locations** form, then press **Aim and place locations**:

| Field | Description |
| --- | --- |
| Gang | Optional. Only members of this gang can use the location (letters, numbers, `_`, `-`; up to 32 characters) |
| Job | Optional. Only players with this job can use it. If you set both a gang and a job, being in either one is enough. If both are empty, everyone can use it |
| Object | Optional prop model, for example `prop_toolchest_01`. The client checks that the model exists. If set, the prop is spawned frozen and invincible where you aim, and players target the prop. If empty, a 2 x 2 x 2 target box is used |

The creator closes and a raycast placement tool starts. Every point you confirm is saved as a new location with its heading. Placement continues until you cancel, then the creator opens again. The list of locations shows each location's coordinates, gang, job and object, with a **Delete** button. A station can have up to 50 locations. Any extra locations are dropped without a warning.

### Duplicate and delete

- **Duplicate station** copies the settings and recipes into a new station named `Name-2` (or the next free number). The locations are **not** copied.
- **Delete station** asks you to confirm, then deletes the station and all of its locations. Its targets and props are removed on every client.

## Logging

Every successful change in the creator is written to `kora_crafting_logs` with the admin's name, license, the callback name and the id of the recipe or station. For a create call the logged id is the name you typed, because the new id is made on the server. Use [`craftLogs`](./commands.md#craftlogs) to read it.
