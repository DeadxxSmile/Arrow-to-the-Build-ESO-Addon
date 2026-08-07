# Changelog

## 0.1.0-alpha.3 — 2026-08-06

- Merged the forced-priority-save correction from Claude's review with the live-export fixes from alpha.2.
- Manual `/attbexport` and player deactivation now bypass the addon's automatic-save throttle. ESO still controls the actual disk-write timing.
- `/attbexport` now reports the number of character snapshots currently held in memory and whether a priority save was requested.
- `/attbstatus` now reports how many characters were loaded when the UI started versus how many are stored now, making cross-character persistence failures visible before checking the Lua file.
- Added a simulated UI-reload regression test proving an existing character survives and a second character is appended.

## 0.1.0-alpha.2 — 2026-08-06

- Fixed class and race IDs by using the dedicated unit-ID APIs.
- Added a reliable localized/fallback gender label.
- Added progression IDs, canonical morph IDs and ranked ability IDs for purchased skills.
- Expanded Champion bar capture to every assignable slot across all three disciplines.
- Normalized non-weapon equipment to `weaponTypeName = "None"`.
- Added live-export regression coverage based on the first real SavedVariables capture.

## 0.1.0-alpha.1 — 2026-08-06

- Added silent multi-character SavedVariables exporter.
- Added identity, progression, attribute, skills, action bars, equipment and Champion Point collectors.
- Added debounced refresh events and priority-save requests.
- Added `/attbexport` and `/attbstatus` diagnostic commands.
- Added versioned data contract, test checklist and desktop integration notes.
