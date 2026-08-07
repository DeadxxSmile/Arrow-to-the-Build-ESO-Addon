# Addon 1.0.0 test checklist

Use this checklist when validating an addon change independently or as part of an ATTB desktop release.

## Clean install

1. Exit ESO.
2. Remove only the ATTB test folders/files from the active profile when a clean test is intended:
   - `AddOns\ArrowToTheBuild`
   - `AddOns\ArrowToTheBuildBridge`
   - `SavedVariables\ArrowToTheBuild.lua`
   - `SavedVariables\ArrowToTheBuildBridge.lua`
3. Install both 1.0.0 addon folders.
4. Launch ESO and confirm both are enabled. The Sync Bridge must report `ArrowToTheBuild` as its required addon.
5. Log into a character.
6. Run `/attbstatus` and confirm version/schema/revision/budget output appears without Lua errors.

Do not delete unrelated ESO SavedVariables.

## Archive capture

- Log into at least two different characters and use `/reloadui` or normal logout/load transitions between them.
- Confirm `ArrowToTheBuild.lua` retains both stable character records.
- Rename behavior must continue to key by stable character ID rather than creating a duplicate based only on display name.
- Confirm identity, attributes, skill lines, purchases/morphs/passives, bars, equipment, and Champion data are present where the character exposes them.

## Bridge budget and current-state capture

- Confirm `/attbstatus` reports the bridge estimated size and 32 KiB budget.
- Test both a low-level character and a heavily progressed character.
- Confirm identity/core progression survives any reduction path.
- Make equipment, action-bar, skill/passive, attribute/progression, and Champion changes and verify the in-memory bridge revision advances.
- Several changes during the local priority cooldown should coalesce into one deferred retry and the bridge should represent the newest complete state rather than a queue of deltas.

## SavedVariables timing test

This is a required real-ESO test because a mocked Lua runtime cannot prove disk behavior.

1. Run `/reloadui` to establish a known physical-file baseline.
2. Record the bridge file modification time.
3. Make a known gameplay change.
4. Record when the addon reports the new in-memory revision.
5. Record when `ArrowToTheBuildBridge.lua` actually changes on disk.
6. Confirm the desktop reflects the new file after the filesystem change.
7. Repeat once with only ATTB addons enabled and once with the normal addon loadout if investigating contention.

Do **not** treat a delayed physical write as proof that capture failed. ESO controls serialization timing.

When a deterministic fresh disk snapshot is needed, use:

```text
/reloadui
```

Do not promise an instant or fixed-minute cadence.

## Natural-save behavior

- `player-activated` should refresh the bridge after a loading screen without spending a new priority request.
- `player-deactivated` should capture pre-transition state and rely on ESO's natural save opportunity.
- The durable archive remains excluded from normal-play SavedVariables autosaving through `DisableSavedVariablesAutoSaving: 1`.
- The bridge remains eligible for normal-play save/priority behavior.

## Desktop reconciliation

With ATTB desktop 2.0.0:

- verify new-character discovery requires user approval;
- verify a newer bridge cannot be rolled back by an older archive;
- verify archive metadata can enrich a newer compact bridge;
- verify omitted bridge sections do not erase the last complete compatible state;
- verify current equipment/action bars/CP do not overwrite authored target gear/bars/CP plans;
- verify Create Build from Character and Adapt Build to Character preserve CURRENT-vs-TARGET ownership;
- verify `/reloadui` creates a reliable fresh desktop snapshot.
