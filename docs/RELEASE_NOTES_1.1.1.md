# Arrow to the Build ESO Addon 1.1.1

Addon 1.1.1 is a correctness and cleanup release for the single-exporter architecture introduced in 1.1.0.

## Fixed

- Corrected localized enum lookup. ESO's two-argument `GetString` API expects a string prefix such as `"SI_ARMORTYPE"`; 1.1.0 incorrectly passed the numeric `SI_*` global in several collectors, which could serialize unrelated settings strings into equipment, trait, skill-type, and gender metadata.
- Equipment collection now uses direct `GetItemEquipType` and `GetItemFunctionalQuality` calls instead of relying on positional unpacking from `GetItemInfo`.
- Action-bar matching now asks ESO to map an unmatched hotbar ability ID back to its skill coordinates before falling back to a unique normalized name.
- Worn inventory events are filtered to `BAG_WORN` and `INVENTORY_UPDATE_REASON_DEFAULT`, reducing needless captures from ordinary durability loss and weapon discharge.
- Restored `DisableSavedVariablesAutoSaving: 1` for the multi-character archive. The archive can exceed ESO's normal-play SavedVariables autosave size limit; `/reloadui`, loading screens, logout, and exit remain the supported persistence path.

## Repository cleanup

- Removed the retired `ArrowToTheBuildBridge` source and manifest from the standalone addon repository.
- Removed the obsolete dual-addon `Schema.lua` layer.
- Updated the PowerShell packager to build one `ArrowToTheBuild` folder and output `ATTB_v1.1.1.zip`.
- Updated README, data-format, desktop-integration, and testing documentation for the current single-addon architecture.

## Compatibility

- ESO API: `101050`
- SavedVariables root schema: `1`
- Character snapshot schema: `2`
- Desktop integration: current Arrow to the Build single-exporter sync path

No build-target data is written by the addon. Addon snapshots remain observed CURRENT character state only.
