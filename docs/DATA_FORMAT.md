# SavedVariables data format - addon 1.0.0

Arrow to the Build 1.0.0 deliberately uses two physical SavedVariables files.

## Durable archive

Addon folder: `ArrowToTheBuild`

SavedVariables global:

```lua
ArrowToTheBuildSavedVariables
```

Physical file:

```text
SavedVariables/ArrowToTheBuild.lua
```

The top-level archive uses **schema 1** and stores a `characters` table keyed by stable character key. Each current compact character record uses **snapshot schema 2**.

Important root fields include:

- `schemaVersion`
- `addonVersion`
- `apiVersion`
- `revision`
- `createdAt`
- `lastUpdatedAt`
- `lastCharacterKey`
- `characters`

A compact character snapshot includes the sections supported by the current client:

- `identity`
- `skills`
- `equipment`
- `champion`
- `diagnostics`
- `completeness`
- `metadata`

The archive retains readable names and richer metadata so the desktop can present useful information even when the small bridge intentionally omits repeated strings.

## Current-character bridge

Addon folder: `ArrowToTheBuildBridge`

SavedVariables global:

```lua
ArrowToTheBuildBridgeSavedVariables
```

Physical file:

```text
SavedVariables/ArrowToTheBuildBridge.lua
```

The bridge uses **schema 2** and holds only the latest current-character payload. It is not a delta log and does not accumulate character history.

Large repeated datasets are packed as tab-separated row blobs with newline-separated rows. Identity keeps the small human-readable values needed for first discovery; skills, equipment, and Champion data prefer stable numeric IDs so the desktop can enrich them from the archive/catalog.

Bridge metadata includes an estimated serialized size, a 32 KiB internal budget, budget status, truncation/reduction information, revision, character identity, and captured sections.

If the bridge needs to reduce payload size, non-essential detail is dropped in deterministic order. Identity and core numeric progression are never the first casualty. The desktop must preserve the latest complete stored/archive sections when a newer reduced bridge omits a section.

## Stable character identity

The desktop identifies a character using all three values:

```text
accountName + worldName + characterId
```

`characterId` is serialized as a string to avoid JavaScript 64-bit precision loss. Character names are display data and are not safe primary keys because they can change.

## Revisions and reconciliation

Archive and bridge revisions are tracked independently.

When both contain the same character:

- a newer bridge snapshot may update current numeric/ID-first state;
- an older archive must never roll that newer state backward;
- the archive may enrich missing readable names/metadata on the newer bridge;
- omitted/reduced bridge sections are reconciled against the last complete compatible data rather than interpreted as deletions.

## Optional fields

ESO APIs differ by patch, account state, and character progression. Missing values are unknown, not automatically zero or false. Importers must tolerate omitted sections and empty Lua tables.

## Disk timing

A revision describes the in-memory data structure that ESO will eventually serialize. It does **not** prove that the physical SavedVariables file changed at the same instant.

ESO owns disk flush timing. `/reloadui`, loading screens, logout, and exit are important persistence points. See [TESTING.md](TESTING.md) for timing tests.
