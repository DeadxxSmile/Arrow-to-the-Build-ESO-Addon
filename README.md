# Arrow to the Build — ESO Companion Addon

A silent Elder Scrolls Online addon that exports character snapshots for the **Arrow to the Build (ATTB)** desktop application.

This repository contains the third alpha of the data bridge, combining the first live SavedVariables fixes with stronger multi-character save diagnostics. It does **not** show build instructions, alter gameplay, spend points, equip items, or communicate over the network. ESO writes the addon data to its normal SavedVariables file; a later ATTB desktop release will watch and import that file.

## Current version

`0.1.0-alpha.3`

## What it exports

For each character logged into after installation:

- Account, megaserver, stable character ID, character name, class, race, alliance and gender
- Character level, Champion Points, zone and available progression points
- Attribute allocation when exposed by the current client, plus current resource pools
- Discovered skill lines and their ranks
- Purchased active skills, morph state, passives and ultimates
- Front and back action bars
- Equipped armor, jewelry, weapons and poisons
- Item IDs, item links, set data, quality, trait, enchantment and requirements
- Purchased Champion stars and all assignable Champion slots across Craft, Warfare and Fitness
- Snapshot schema, addon version, API version, timestamps and diagnostics

ESO stores all discovered characters in one SavedVariables file. Each character has an independent snapshot keyed by account, megaserver and stable character ID.

## Manual installation

1. Close ESO.
2. Extract the install ZIP so this folder exists:

   `Documents\Elder Scrolls Online\live\AddOns\ArrowToTheBuild`

3. Launch ESO and enable **Arrow to the Build** in Add-ons.
4. Log into each character once.
5. Log out, change zones, run `/reloadui`, or exit ESO so the client has an opportunity to write SavedVariables.

The exported file is normally:

`Documents\Elder Scrolls Online\live\SavedVariables\ArrowToTheBuild.lua`

The account may use `liveeu` or `pts` instead of `live`. Those environments use separate SavedVariables files, so characters captured on different environments will not appear together.

## Test commands

The addon has no automatic interface. Two manual diagnostic commands are included:

- `/attbexport` — refreshes the current character snapshot, reports the in-memory character count, and deliberately requests a best-effort priority SavedVariables save.
- `/attbstatus` — reports addon/schema version, the count loaded at UI startup, the count stored now, revision, and active megaserver.

These commands only write a short chat message when explicitly used.

## Important behavior

- A character appears only after that character has been logged into while the addon is enabled.
- Existing character snapshots are preserved when another character is captured, provided ESO wrote the earlier in-memory table before the UI was reloaded for the next character.
- Character renames do not create duplicates because snapshots use the stable character ID.
- SavedVariables writes are controlled by ESO. The in-memory snapshot updates immediately, while the physical Lua file may update during a loading screen, `/reloadui`, logout, exit, or another client save opportunity. Forced requests bypass only ATTB's own throttle, not ESO's limits.
- The addon never executes or reads files from the ATTB desktop app.

## Repository layout

- `addon/ArrowToTheBuild/` — distributable ESO addon folder
- `docs/DATA_FORMAT.md` — SavedVariables schema
- `docs/TESTING.md` — alpha test checklist
- `docs/DESKTOP_INTEGRATION.md` — contract for the future Electron importer
- `tests/mock_test.lua` — mocked ESO runtime regression test

## License

MIT. See [LICENSE](LICENSE).
