# Arrow to the Build ESO Companion Addon 1.0.0

The first stable addon release freezes the local SavedVariables contract used by **Arrow to the Build desktop 2.0.0**.

## Included components

- **ArrowToTheBuild** - durable multi-character archive with compact schema-2 character snapshots and richer readable metadata.
- **ArrowToTheBuildBridge** - compact current-character bridge with a 32 KiB internal budget, ID-first packed data, deterministic reduction, deferred/coalesced priority-save retry, and status diagnostics.

## Captured data

The addon can export character identity, progression, attributes, skill lines, purchased abilities/morphs/passives, action bars, equipment, and Champion Point state through ESO SavedVariables.

## Sync behavior

ESO-not the addon-controls when SavedVariables reach disk. Loading screens, logout, exit, and other client save opportunities may flush data naturally. `/reloadui` is the reliable user-controlled refresh path when an immediate fresh disk snapshot is needed.

The bridge improves normal-play opportunities without claiming to force immediate serialization.

## Privacy

Both components are silent and local-only. They do not communicate over the network, automate gameplay, spend points, equip items, or read desktop-app files.

## Desktop pairing

ATTB desktop 2.0.0 watches both sources, treats newer bridge data as CURRENT character reality, uses the archive to enrich omitted readable metadata, and keeps TARGET build planning owned by the desktop/user.
