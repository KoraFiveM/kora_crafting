# kora_crafting agent guide

kora_crafting adds in-game crafting stations and recipes managed through a Kora NUI creator and stored in MySQL. Shared config and constants live in `shared/`, client targets/menu/creator in `client/`, and schema/data/callbacks/crafting/logs in `server/`; `fft_hooks.lua` is an optional dev-only client hook.

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview and the documentation map. Layout: `index.md` (hub), `installation.md`, `how-to-use.md`, `commands.md` (`/craftCreator`, `craftLogs`), `api/` (`index.md` plus `skills-integration.md` for `Config.Skills`), and topic pages (`configuration`, `creator`, `crafting`, `items`, `exports`, `events`, `database`, `troubleshooting`). Update the page that matches the change.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.

## Shared contribution standards

Read [CONTRIBUTING.md](CONTRIBUTING.md) before editing. Humans and agents follow
the same Kora standards and self-contained local Lua checks. Preserve the domain
constraints above and in module guides; record policy conflicts explicitly.
