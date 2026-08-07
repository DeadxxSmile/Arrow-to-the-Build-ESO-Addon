# Desktop integration contract

This document describes the importer planned for the ATTB Electron app. It is not implemented by the addon.

## File discovery

The desktop app should derive the SavedVariables file from the selected ESO environment root:

```text
<Elder Scrolls Online root>/SavedVariables/ArrowToTheBuild.lua
```

The common environment roots are `live`, `liveeu`, and `pts`. The user must be able to browse to a nonstandard location.

## Watching safely

The Electron main process should:

1. Watch the specific SavedVariables file and its parent directory.
2. Debounce filesystem events.
3. Wait until file size and modification time stabilize.
4. Parse the restricted Lua-table data format without executing Lua.
5. Reject functions, metatables, arbitrary expressions and executable statements.
6. Compare top-level `revision` before processing.
7. Reattach the watcher when ESO replaces the file.

## Character matching

Use:

```text
accountName + worldName + characterId
```

Do not match only by character name.

## Import behavior

- Existing linked ATTB characters may update their observed game state automatically.
- Newly discovered addon characters remain pending unless automatic character creation is enabled.
- Addon snapshots must never replace the chosen ATTB build, recommendations, user notes, or manually authored build data.
- Missing optional fields mean unknown, not zero.
- Characters absent from a newer snapshot file must not be deleted automatically.

## Planned desktop controls

```text
Settings > App Settings > ESO Addon Integration
```

- Enable addon synchronization
- Addon installation folder
- SavedVariables file or detected environment
- Get Addon / installation guide
- Rescan now
- Automatically add all discovered characters

The Add Character page will replace `Import Another Build` with `Import Data From Addon`.
