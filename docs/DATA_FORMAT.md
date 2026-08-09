# SavedVariables data format - addon 1.1.1

Arrow to the Build 1.1.1 uses one physical SavedVariables file and one multi-character archive.

## Archive

Addon folder:

```text
ArrowToTheBuild
```

SavedVariables global:

```lua
ArrowToTheBuildSavedVariables
```

Physical file:

```text
SavedVariables/ArrowToTheBuild.lua
```

The top-level archive uses **schema 1** and stores a `characters` table keyed by stable character key. Each character record uses **snapshot schema 2** and the `compact` data profile.

Important root fields include:

- `schemaVersion`
- `addonVersion`
- `apiVersion`
- `revision`
- `createdAt`
- `lastUpdatedAt`
- `lastCharacterKey`
- `characters`

A character snapshot contains:

- `snapshotSchemaVersion`
- `dataProfile`
- `addonVersion`
- `apiVersion`
- `capturedAt`
- `captureReason`
- `identity`
- `skills`
- `equipment`
- `champion`
- `metadata`

## Stable character identity

The desktop identifies a character using all three values:

```text
accountName + worldName + characterId
```

ESO API 101050 returns `GetCurrentCharacterId()` as a string. Character names are display data and are not safe primary keys because they can change.

## Identity

The identity section includes account/world/character identity plus current progression data such as:

- class, race, alliance, and gender IDs/names;
- level and Champion Point values;
- zone;
- available Skill Points and attribute points;
- spent Magicka/Health/Stamina attribute points and current/max power values.

## Skills

The skills section contains discovered skill lines, purchased abilities/passives, action bars, and the active weapon pair.

Numeric IDs are authoritative. Localized display names are convenience metadata.

Action-bar entries retain the raw hotbar `abilityId`. When that ID does not directly equal the progression ID stored for a purchased skill, the exporter first asks ESO to map the ability ID back to its skill coordinates. A unique normalized-name fallback remains only as a final compatibility path.

## Equipment

Equipment entries include the worn slot, item ID/name, quality, requirements, equip/item/armor/weapon types, trait, set, and enchantment metadata where available.

Enum fields keep both the numeric enum value and a localized name. Version 1.1.1 resolves these names with ESO's documented string-prefix form, for example:

```lua
GetString("SI_ARMORTYPE", armorType)
```

Consumers should continue to treat numeric IDs as the stable value and display text as localization metadata.

## Champion Points

Champion data includes total earned points, discipline spent/unspent totals, purchased stars, and the current Champion Bar slots.

## Revisions and partial captures

The archive root `revision` increments when a new snapshot is captured. Event-driven updates can refresh only the affected sections while carrying forward unchanged sections from the previous snapshot for that character.

Every capture refreshes identity. A new character and player activation/deactivation use full captures.

`metadata.capturedSections` records which sections were actively recollected for that snapshot; carried-forward sections remain present in the character record.

## Optional fields

ESO APIs can legitimately return empty strings, zero enum values, or absent optional data depending on item type and character progression. Importers must tolerate omitted Lua keys and empty tables.

## Disk timing

A revision describes the in-memory data structure that ESO will eventually serialize. It does **not** prove that the physical SavedVariables file changed at the same instant.

The manifest disables normal-play SavedVariables autosaving because this multi-character archive can exceed ESO's small-file autosave limits. ESO still owns persistence at loading screens, `/reloadui`, logout, and exit.

When a deterministic fresh physical snapshot is needed for desktop testing, use:

```text
/reloadui
```

See [TESTING.md](TESTING.md) for the validation checklist.
