# SavedVariables data format

The addon declares one SavedVariables global:

```lua
ArrowToTheBuildSavedVariables
```

ESO serializes that global to:

```text
SavedVariables/ArrowToTheBuild.lua
```

## Top-level structure

```lua
ArrowToTheBuildSavedVariables = {
    schemaVersion = 1,
    addonVersion = "0.1.0-alpha.3",
    apiVersion = 101050,
    revision = 12,
    createdAt = 1786068000,
    lastUpdatedAt = 1786069200,
    lastPrioritySaveRequestedAt = 1786069200,
    lastPrioritySaveCharacterKey = "@Account|NA Megaserver|1234567890123456",
    lastPrioritySaveWasForced = true,
    lastCharacterKey = "@Account|NA Megaserver|1234567890123456",
    characters = {
        ["@Account|NA Megaserver|1234567890123456"] = {
            snapshotSchemaVersion = 1,
            addonVersion = "0.1.0-alpha.3",
            apiVersion = 101050,
            capturedAt = 1786069200,
            captureReason = "player-activated",
            identity = {},
            skills = {},
            equipment = {},
            champion = {},
            diagnostics = {},
            completeness = {},
            metadata = {},
        },
    },
}
```

## Stable identity

The desktop app must identify a character with all three fields:

```text
accountName + worldName + characterId
```

`characterId` is exported as a string to avoid loss of 64-bit precision in JavaScript.

Do not use character name as the primary key. Names may change.

## Revision behavior

`revision` increases every time any character snapshot is replaced. The desktop importer can ignore a filesystem event when the parsed revision has not changed.

Each character snapshot also keeps:

- `metadata.firstSeenAt`
- `metadata.lastSeenAt`
- `metadata.captureCount`

## Optional fields

ESO APIs can differ between patches, account states, and progression systems. Fields unavailable to the client are stored as `nil` and omitted by ESO's serializer. Importers must treat absent fields as unknown rather than as zero or false.

## Diagnostics

Collector failures are contained in:

```lua
diagnostics = {
    warnings = {},
    errors = {},
}
```

A partial snapshot remains importable. The `completeness` object indicates which major sections were collected.

## Skill identity fields

Purchased progression skills may contain several numeric IDs:

- `baseAbilityId` — the unmorphed skill family ID.
- `morphAbilityId` — the canonical selected morph ID when the current client exposes it.
- `rankedAbilityId` — the current rank-specific progression ability ID.
- `abilityId` — preferred current ID, choosing morph, ranked, then base in that order.
- `progressionId` and `progressionIndex` — ESO progression identifiers used for reconciliation.

Importers should retain the names as display data, but prefer numeric identity fields for locale-independent matching.

## Champion slots

`champion.slotted.slots` spans the full assignable Champion bar range. Each entry includes its action-slot index and required discipline ID/name so Craft, Warfare and Fitness slots can be reconstructed separately.


## Save-request diagnostics

`lastPrioritySaveRequestedAt`, `lastPrioritySaveCharacterKey`, and `lastPrioritySaveWasForced` record the most recent priority-save request accepted by the addon-side API call. They do not prove the operating-system file has already changed; ESO owns serialization timing.

The `/attbstatus` command also reports two runtime-only counts:

- `loaded at UI start` — character records present when this UI session loaded the SavedVariables table.
- `stored now` — records currently present after captures in this UI session.

On a second character, `loaded at UI start 1` followed by `stored now 2` confirms the first record was loaded and the second was appended before disk inspection.
