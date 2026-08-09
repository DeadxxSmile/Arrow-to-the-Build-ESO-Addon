# Addon 1.1.1 test checklist

Use this checklist when validating an addon change independently or as part of an ATTB desktop release.

## Clean install

1. Exit ESO.
2. Remove only the ATTB test folders/files from the active profile when a clean test is intended:
   - `AddOns\ArrowToTheBuild`
   - obsolete `AddOns\ArrowToTheBuildBridge` if it exists from an older release;
   - `SavedVariables\ArrowToTheBuild.lua` only when a clean archive is specifically required;
   - obsolete `SavedVariables\ArrowToTheBuildBridge.lua` if it exists from an older release.
3. Install the single `ArrowToTheBuild` 1.1.1 addon folder.
4. Launch ESO and confirm **Arrow to the Build** is enabled with no missing dependency.
5. Log into a character.
6. Run `/attbstatus` and confirm version `1.1.1`, API `101050`, character count, and revision output appear without Lua errors.

Do not delete unrelated ESO SavedVariables.

## Archive capture

- Log into at least two different characters and use `/reloadui` or normal logout/load transitions between them.
- Confirm `ArrowToTheBuild.lua` retains both stable character records.
- Rename behavior must continue to key by stable character ID rather than creating a duplicate based only on display name.
- Confirm identity, attributes, skill lines, purchases/morphs/passives, bars, equipment, and Champion data are present where the character exposes them.

## Enum-label regression test

This is required for 1.1.1 because 1.1.0 accidentally passed numeric `SI_*` globals to the two-argument `GetString` overload.

After `/reloadui`, inspect the current character snapshot and verify:

- `skillTypeName` contains sensible ESO categories rather than unrelated settings text;
- worn armor has `armorTypeName` such as `Light`, `Medium`, or `Heavy` matching its numeric `armorType`;
- `equipTypeName` describes the equipment slot/type rather than settings labels such as `Graphics Options`, `Brightness`, or `Reset to Defaults`;
- `trait.name` describes the actual item trait rather than gamepad/settings prompts;
- weapon type names describe the weapon rather than unrelated UI strings;
- gender display text is sensible for the numeric gender value;
- the SavedVariables file contains no repeated `Input Language Changed to:` corruption caused by enum lookup.

Numeric enum values must remain present alongside localized display names.

## Action-bar matching

- Verify both primary and backup bars contain the same abilities shown by ESO.
- For skills whose hotbar action ID differs from the progression ability ID, confirm the slot still resolves to the correct skill line/progression.
- Prefer `matchMethod = "ability-id"` or `matchMethod = "ability-keys"` when ESO can identify the skill directly.
- `matchMethod = "name"` is allowed only as the final unique-name compatibility fallback.
- Verify duplicate skill names never cause a slot to be attached to the wrong skill line.

## Equipment event behavior

The equipment listener is filtered at registration time to `BAG_WORN` plus `INVENTORY_UPDATE_REASON_DEFAULT`.

- Equip or unequip a piece and confirm equipment refreshes.
- Lose ordinary armor durability in combat and confirm this no longer causes continuous equipment captures.
- Weapon charge consumption should not create continuous equipment captures.
- Repairing an equipped item may still produce a default inventory update; an occasional refresh for that case is acceptable.

## SavedVariables timing test

This is a required real-ESO test because a mocked Lua runtime cannot prove disk behavior.

1. Run `/reloadui` to establish a known physical-file baseline.
2. Record the `ArrowToTheBuild.lua` modification time.
3. Make a known gameplay change.
4. Run `/attbstatus` if useful to confirm an in-memory capture/revision advanced.
5. Record when `ArrowToTheBuild.lua` actually changes on disk.
6. Confirm the desktop reflects the new file after the filesystem change.
7. Repeat once with only ATTB enabled and once with the normal addon loadout if investigating save contention.

Do **not** treat a delayed physical write as proof that capture failed. ESO controls serialization timing.

When a deterministic fresh disk snapshot is needed, use:

```text
/reloadui
```

Do not promise an instant or fixed-minute cadence.

## SavedVariables policy

- The single archive manifest must contain `## DisableSavedVariablesAutoSaving: 1`.
- `/reloadui`, loading screens, logout, and exit remain the persistence path.
- The addon must not reintroduce `RequestAddOnSavedVariablesPrioritySave` or a small bridge merely to chase normal-play disk writes for a large archive.

## Desktop integration

With a desktop build that supports the single exporter:

- verify new-character discovery requires user approval;
- verify current equipment/action bars/CP do not overwrite authored target gear/bars/CP plans;
- verify Create Build from Character and Adapt Build to Character preserve CURRENT-vs-TARGET ownership;
- verify linking is stable across a character rename because identity uses account + world + character ID;
- verify `/reloadui` creates a reliable fresh desktop snapshot;
- verify an obsolete bridge folder/file is not required after migration.

## Source-level regression checks

The desktop repository includes static source tests for the bundled addon. Before packaging a desktop release, run its normal test suite and confirm the addon-source regression test passes. In particular, no current addon source should contain a call shaped like:

```lua
GetString(SI_SOMETHING, value)
```

for an enum prefix. The correct two-argument form is:

```lua
GetString("SI_SOMETHING", value)
```
