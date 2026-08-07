# Alpha testing checklist

## Installation

- [ ] Extract `ArrowToTheBuild` directly into the active ESO `AddOns` directory.
- [ ] Confirm ESO lists **Arrow to the Build** and reports no dependency errors.
- [ ] Confirm the addon is not marked out of date for API 101050.
- [ ] Log into one character without Lua errors.

## First snapshot

- [ ] Run `/attbstatus`; it reports version `0.1.0-alpha.3`.
- [ ] Run `/attbexport`; it confirms a snapshot was captured in memory.
- [ ] Run `/reloadui` or log out.
- [ ] Confirm `SavedVariables/ArrowToTheBuild.lua` exists.
- [ ] Confirm the file contains `ArrowToTheBuildSavedVariables`.
- [ ] Confirm the active character appears under `characters`.

## Character identity

- [ ] Account display name is correct.
- [ ] Megaserver is correct.
- [ ] Character ID is a quoted string.
- [ ] Character name, class, race, alliance and level are correct.
- [ ] Class and race IDs are non-zero and match the character.
- [ ] Gender name is localized or a valid Female/Male fallback.

## Skills and bars

- [ ] Discovered skill lines are present.
- [ ] Purchased actives, morphs and passives are present.
- [ ] Morphed skills contain a non-empty `morphAbilityId` and `abilityId` identifies the selected morph.
- [ ] Primary-bar abilities match the game.
- [ ] Backup-bar abilities match the game after level 15.
- [ ] Ultimate slots are stored as position 6.

## Equipment

- [ ] Armor and jewelry slots are present.
- [ ] Front and back weapons are present.
- [ ] Set names and IDs appear for set pieces.
- [ ] Trait, enchantment and quality values are present.

## Champion Points

- [ ] Purchased Champion stars are present on a CP character.
- [ ] Slotted Champion stars match all three constellations.
- [ ] Champion slot entries include `disciplineId`, `disciplineName` and the full assignable slot range.
- [ ] A non-CP character produces an empty but valid Champion section.

## Multiple characters

Use two characters on the same megaserver and the same ESO environment (`live`, `liveeu`, or `pts`).

- [ ] On the first character, run `/attbexport`; the message reports `1 character(s) stored in memory`.
- [ ] Run `/attbstatus`; note `stored now 1`.
- [ ] Run `/reloadui`, log out, or change characters through a normal loading screen.
- [ ] On the second character, run `/attbstatus` before exporting. It should report `loaded at UI start 1`.
- [ ] Run `/attbexport`; the message should report `2 character(s) stored in memory`.
- [ ] Run `/attbstatus`; it should report `stored now 2`.
- [ ] Run `/reloadui` or log out, then confirm both snapshots remain in the same SavedVariables file.
- [ ] Return to the first character and confirm its existing stable-ID record updates rather than duplicating.

If the second character reports `loaded at UI start 0`, the first character was not present in the SavedVariables table loaded for that UI session. Record whether the characters were on different megaservers or `live`/`liveeu`/`pts` environments, and preserve the Lua file before further testing.

## Event refreshes

After each action, allow the debounce to finish, then `/reloadui` before checking the disk file.

- [ ] Gain a level.
- [ ] Purchase or morph a skill.
- [ ] Change an action-bar slot.
- [ ] Change equipped gear.
- [ ] Spend or slot Champion Points.
- [ ] Change an attribute point where applicable.

## Error reporting

When a Lua error occurs, capture:

- The full error text and stack
- Which character and server were active
- The action performed immediately beforehand
- The generated SavedVariables file, with account and character names redacted if desired
