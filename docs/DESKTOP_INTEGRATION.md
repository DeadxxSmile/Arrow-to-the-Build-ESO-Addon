# Desktop integration contract - addon 1.0.0

The Arrow to the Build desktop app consumes both SavedVariables files as restricted data. It does not execute Lua.

## Source priority

The two files have different jobs:

- `ArrowToTheBuild.lua` - durable, fuller, multi-character archive and display metadata.
- `ArrowToTheBuildBridge.lua` - smaller, potentially fresher current-character state.

The desktop watches both sources and keeps independent revision tracking. A fresher bridge must not be rolled back by an older archive. The archive may enrich names and other omitted metadata when doing so does not replace newer numeric state.

## CURRENT versus TARGET

Addon data represents **observed CURRENT reality** only.

The desktop application owns **TARGET planning**, including:

- selected build
- future recommendations
- variants/loadouts
- Build Notes
- target gear stages
- authored Champion Point plans
- Build Editor content and revisions

Sync must never silently overwrite those target-owned fields.

## Character discovery

A newly observed character is not automatically created or linked in ATTB.

Character identity is:

```text
accountName + worldName + characterId
```

The user explicitly chooses whether to:

- add the character;
- link a compatible existing ATTB character;
- create a new build from the observed character;
- adapt an existing compatible-class target build.

Class mismatches are rejected.

## Overrides

The desktop can optionally layer per-field local overrides over the latest observed snapshot. New addon data continues updating underneath an override. Restoring a field removes only that override and immediately exposes the latest live value again.

Turning override mode off removes synchronized-data overrides; it does not delete the character, target build, notes, or planning content.

## SavedVariables timing

The filesystem watcher reacts when ESO changes the physical files. It does not assume a fixed autosave interval.

`RequestAddOnSavedVariablesPrioritySave()` is best effort and rate limited. It is not an immediate write primitive. `/reloadui` is the reliable user-controlled path when a fresh physical snapshot is needed for testing or troubleshooting.
