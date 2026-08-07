# Arrow to the Build - ESO Companion Addon

The **Arrow to the Build ESO Companion Addon** is the local, data-only ESO side of [Arrow to the Build (ATTB)](https://github.com/DeadxxSmile/Arrow-to-the-Build), an offline-first Windows character tracker and Build Editor for *The Elder Scrolls Online*.

**Current addon version: 1.0.0**

The stable 1.0 release contains **two addon components on purpose**:

- `ArrowToTheBuild` - a durable, fuller multi-character archive.
- `ArrowToTheBuildBridge` - a deliberately small current-character SavedVariables bridge.

The desktop app bundles both folders and can install, repair, and update them automatically. This repository exists for source review, manual installation/builds, technical documentation, and independent addon development.

## What the addon does

When a character is played with the addon enabled, ATTB can capture observed ESO state such as:

- account, megaserver, stable character ID, character name, class, race, alliance, and gender
- character level, Champion Points, available progression points, and attribute allocation
- discovered skill lines and line ranks
- purchased active abilities, current morphs, ultimates, and passive ranks
- front and back action bars
- equipped armor, jewelry, weapons, poisons, traits, enchants, and set information
- purchased Champion stars and slotted Craft, Warfare, and Fitness stars
- timestamps, revision information, data-completeness flags, and diagnostics

The addon **does not** show build instructions, choose skills, spend points, equip gear, automate combat, send network requests, or read files from the desktop application. It only writes normal ESO SavedVariables.

## Why there are two addon folders

ESO serializes SavedVariables by addon. Keeping the full archive and the small bridge in separate addons gives them separate physical SavedVariables files and separate save opportunities.

### ArrowToTheBuild - durable archive

The main addon maintains the richer multi-character history in:

```text
SavedVariables\ArrowToTheBuild.lua
```

It preserves fuller readable metadata and is intended to persist at normal ESO save points such as loading screens, `/reloadui`, logout, and exit. Its manifest disables normal-play SavedVariables autosaving so the much larger archive does not compete with the compact bridge.

### ArrowToTheBuildBridge - current-character bridge

The bridge stores one compact, ID-first current-character snapshot in:

```text
SavedVariables\ArrowToTheBuildBridge.lua
```

Its internal soft budget is **32 KiB**. Repeated data such as skills, equipment, and Champion details is compacted so the current-character file remains small. If a payload ever approaches the budget, the bridge reduces non-essential detail in a deterministic order while preserving identity and core numeric progression.

The desktop can combine a newer bridge snapshot with older archive metadata without rolling back newer observed values.

## Important: SavedVariables refresh timing

**ESO controls when SavedVariables are actually written to disk.**

The addon may capture a change in memory immediately, and the bridge may request a best-effort priority save, but neither component can force ESO to serialize the physical Lua file at an exact moment. ESO also rate-limits priority save requests, and a heavily modded client can have additional SavedVariables contention.

Natural disk-write opportunities include:

- loading screens
- logout
- game exit
- other ESO save opportunities

If Arrow to the Build on the desktop looks stale and you want a reliable user-controlled refresh, run:

```text
/reloadui
```

That is the recommended **refresh now** path. Do not expect or advertise an instant or fixed-minute synchronization interval.

Background references used by ATTB for this limitation:

- [ESOUI forum: SavedVariables save timing](https://www.esoui.com/forums/showthread.php?t=8957)
- [ESOUI wiki: Storing data and accessing files](https://wiki.esoui.com/Storing_data_and_accessing_files)

The bridge includes a coalesced deferred retry for changes captured during its local priority-request cooldown, but ESO remains the final authority over disk persistence.

## In-game diagnostic commands

The addon has no normal UI. These commands write short diagnostic messages to chat only when you use them:

- `/attbstatus` - reports current archive/bridge revision state, capture details, bridge budget status, and deferred/dirty save diagnostics.
- `/attbexport` - captures a full current-character snapshot and requests best-effort bridge priority-save behavior.
- `/attbcharacters` - lists character records currently held by the durable archive.

For a clean desktop refresh test, `/reloadui` remains more reliable than repeatedly issuing `/attbexport`, because ESO controls the actual file flush.

## Desktop behavior and data ownership

The desktop app identifies a synced character by:

```text
accountName + worldName + characterId
```

A character rename therefore updates the same link instead of creating a duplicate.

New characters are never silently added or merged by the desktop app. The user explicitly chooses whether to add the character, link an existing profile, create a new build from current state, or adapt an existing build.

Observed ESO data is **CURRENT reality**. The desktop application owns **TARGET planning**. Synchronization must never silently overwrite the selected target build, Build Notes, build variants, authored recommendations, future gear stages, or other user-owned planning data.

## Installation

### Recommended: let the desktop app install it

Install [Arrow to the Build](https://github.com/DeadxxSmile/Arrow-to-the-Build), then use the automatic synchronization setup or **Settings → General Settings → Install / Repair Addon**.

### Manual installation

Copy both folders from `addon\` into the active ESO profile's `AddOns` directory so these paths exist:

```text
Documents\Elder Scrolls Online\live\AddOns\ArrowToTheBuild
Documents\Elder Scrolls Online\live\AddOns\ArrowToTheBuildBridge
```

`liveeu` and `pts` use their own profile roots and SavedVariables.

Enable both addons in ESO. The Sync Bridge depends on the main Arrow to the Build addon.

## Build an installable addon ZIP from source

Windows PowerShell is enough; no Node.js toolchain is required.

From the repository root:

```powershell
.\BUILD-ADDON.ps1
```

The script validates the two manifests and matching versions, then creates:

```text
dist\ATTB-ESOAddon-Built-v1.0.0.zip
```

That built ZIP contains `ArrowToTheBuild\` and `ArrowToTheBuildBridge\` at its root for normal addon-manager/manual installation workflows.

## Repository layout

```text
Arrow-to-the-Build-ESO-Addon/
├── addon/
│   ├── ArrowToTheBuild/
│   └── ArrowToTheBuildBridge/
├── docs/
│   ├── DATA_FORMAT.md
│   ├── DESKTOP_INTEGRATION.md
│   ├── TESTING.md
│   └── RELEASE_NOTES_1.0.0.md
├── BUILD-ADDON.ps1
├── LICENSE
└── README.md
```

## Compatibility

Addon 1.0.0 targets ESO API version `101050` and the ATTB 2.0 desktop data contracts:

- durable SavedVariables root schema: **1**
- durable compact character snapshot schema: **2**
- bridge SavedVariables schema: **2**

The desktop parser is intentionally data-only and never evaluates Lua as executable code.

## License and disclaimer

The addon source is licensed under the MIT License. See [LICENSE](LICENSE).

Arrow to the Build is an unofficial community project. It is not affiliated with, endorsed by, or sponsored by ZeniMax Media, Bethesda Softworks, or *The Elder Scrolls Online*. Game names, marks, and game assets belong to their respective owners.
