# Desktop integration contract - addon 1.1.1

The Arrow to the Build desktop app consumes `ArrowToTheBuild.lua` as restricted data. It does not execute Lua.

## Source

Current addon releases use one source:

```text
SavedVariables/ArrowToTheBuild.lua
```

The former `ArrowToTheBuildBridge.lua` source was retired in addon 1.1.0. Desktop builds that support the single-exporter architecture migrate positively identified legacy bridge artifacts and then watch only the current archive.

The archive contains multiple character snapshots and a root revision. The desktop waits for a stable file write, parses it with the restricted SavedVariables parser, and skips unchanged revisions.

## CURRENT versus TARGET

Addon data represents **observed CURRENT reality** only.

The desktop application owns **TARGET planning**, including:

- selected build;
- future recommendations;
- variants/loadouts;
- Build Notes;
- target gear stages;
- authored Champion Point plans;
- Build Editor content and revisions.

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

The desktop can optionally layer per-field local overrides over the latest observed snapshot. New addon data continues updating underneath an override. Restoring a field removes only that override and immediately exposes the latest observed value again.

Turning override mode off removes synchronized-data overrides; it does not delete the character, target build, notes, or planning content.

## Numeric IDs and display metadata

The addon exports stable numeric IDs alongside localized display strings. Importers should prefer IDs for identity/matching and use names for presentation.

Addon 1.1.1 fixes enum display-name generation so armor, weapon, equip, item, trait, skill-type, and gender labels use ESO's documented two-argument `GetString` string-prefix form.

Action bars retain the raw hotbar ability ID. The exporter first attempts direct ID matching, then ESO's inverse ability-to-skill-coordinate lookup, then a unique-name fallback. The desktop should preserve `matchMethod` for diagnostics rather than assuming every hotbar ID equals the skill progression ID.

## SavedVariables timing

The filesystem watcher reacts when ESO changes the physical archive. It does not assume a fixed autosave interval.

The current manifest contains:

```text
## DisableSavedVariablesAutoSaving: 1
```

The multi-character archive can exceed ESO's normal-play autosave size limit, so ATTB deliberately relies on ESO persistence points such as loading screens, logout, exit, and `/reloadui` instead of requesting priority saves.

`/reloadui` is the reliable user-controlled path when a fresh physical snapshot is needed for testing or troubleshooting.
