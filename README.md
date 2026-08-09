# Arrow to the Build - ESO Companion Addon

The **Arrow to the Build ESO Companion Addon** is the local, data-only ESO side of [Arrow to the Build](https://github.com/DeadxxSmile/Arrow-to-the-Build), an offline-first Windows character tracker and Build Editor for *The Elder Scrolls Online*.

**Current addon version: 1.1.1**  
**ESO API: 101050**

Version 1.1 uses **one addon folder and one SavedVariables file**. The former `ArrowToTheBuildBridge` component was retired; it should not be installed with current releases.

## What the addon does

When a character is played with the addon enabled, ATTB captures observed ESO state such as:

- account, megaserver, stable character ID, character name, class, race, alliance, and gender;
- character level, Champion Points, available progression points, and attribute allocation;
- discovered skill lines and line ranks;
- purchased active abilities, current morphs, ultimates, and passive ranks;
- front and back action bars;
- equipped armor, jewelry, weapons, traits, enchants, and set information;
- purchased Champion stars and slotted Craft, Warfare, and Fitness stars;
- timestamps, revision information, capture reasons, and basic metadata.

The addon **does not** show build instructions, choose skills, spend points, equip gear, automate combat, send network requests, or read files from the desktop application. It only writes normal ESO SavedVariables.

## One archive, one source of truth

The addon stores its multi-character archive in:

```text
SavedVariables\ArrowToTheBuild.lua
```

The SavedVariables global is:

```lua
ArrowToTheBuildSavedVariables
```

Characters are keyed by:

```text
accountName + worldName + characterId
```

A rename therefore updates the same character identity instead of relying on the display name as a primary key.

## Important: SavedVariables refresh timing

**ESO controls when SavedVariables are actually written to disk.** The addon can update its in-memory archive immediately, but it cannot force the physical Lua file to change at an exact moment.

ATTB's archive is intentionally excluded from ESO's normal-play SavedVariables autosave queue:

```text
## DisableSavedVariablesAutoSaving: 1
```

ESO's normal-play autosave mechanism is intended for small SavedVariables payloads and defers larger files to a loading screen. A multi-character ATTB archive can grow well beyond that small-file threshold, so ATTB relies on the normal persistence points instead of competing for periodic autosaves.

Natural write opportunities include loading screens, logout, game exit, and `/reloadui`.

If Arrow to the Build on the desktop looks stale and you want a reliable user-controlled refresh, run:

```text
/reloadui
```

Do not expect or advertise an instant or fixed-minute synchronization interval.

Useful background references:

- [ESOUI forum: SavedVariables save timing](https://www.esoui.com/forums/showthread.php?t=8957)
- [ESOUI forum: SavedVariables autosaving](https://www.esoui.com/forums/showthread.php?p=39013)

## 1.1.1 correctness hardening

Version 1.1.1 fixes issues found during a full review against ESO API 101050 and ESOUI addon-development guidance:

- enum display strings now use the documented `GetString("SI_PREFIX", enumValue)` form;
- equipment uses direct item APIs for equip type and functional quality rather than positional `GetItemInfo` unpacking;
- action-bar matching uses ESO's ability-ID-to-skill-coordinate API before the final unique-name fallback;
- worn inventory events are filtered to `BAG_WORN` and normal inventory updates to avoid durability-loss and weapon-discharge event spam;
- the large archive again opts out of normal-play SavedVariables autosaving;
- the standalone repository now matches the desktop's current single-addon architecture instead of shipping the retired bridge.

The numeric IDs remain the authoritative data in snapshots. Human-readable localized names are convenience metadata for the desktop UI.

## In-game diagnostic commands

The addon has no normal UI. These commands write short diagnostic messages to chat only when you use them:

- `/attbstatus` - reports addon/API/world information, stored character count, revision, latest capture, and pending refresh state.
- `/attbexport` - captures a full current-character snapshot in memory. Use `/reloadui` afterward when you need it written to disk immediately.
- `/attbcharacters` - lists character records currently held by the archive.

## Desktop behavior and data ownership

Observed ESO data is **CURRENT reality**. The desktop application owns **TARGET planning**. Synchronization must never silently overwrite the selected target build, Build Notes, build variants, authored recommendations, future gear stages, or other user-owned planning data.

New characters are never silently added or merged by the desktop app. The user explicitly chooses whether to add the character, link an existing profile, create a new build from current state, or adapt an existing build.

## Installation

### Recommended: let the desktop app install it

Install [Arrow to the Build](https://github.com/DeadxxSmile/Arrow-to-the-Build), then use the automatic synchronization setup or **Settings → General Settings → Install / Repair Addon**.

### Manual installation

Copy this folder into the active ESO profile's `AddOns` directory:

```text
addon\ArrowToTheBuild
```

so the final path is:

```text
Documents\Elder Scrolls Online\live\AddOns\ArrowToTheBuild
```

`liveeu` and `pts` use their own profile roots and SavedVariables.

If an old `ArrowToTheBuildBridge` folder remains from a pre-1.1 install, remove it. Current releases do not use it.

## Build an installable addon ZIP from source

Windows PowerShell is enough; no Node.js toolchain is required.

From the repository root:

```powershell
.\BUILD-ADDON.ps1
```

The script validates the current manifest, refuses to package a leftover bridge folder, and creates:

```text
dist\ATTB_v1.1.1.zip
```

The ZIP contains `ArrowToTheBuild\` at its root for normal addon-manager/manual installation workflows.

## Repository layout

```text
Arrow-to-the-Build-ESO-Addon/
├── addon/
│   └── ArrowToTheBuild/
│       ├── Collectors/
│       ├── ArrowToTheBuild.txt
│       ├── Namespace.lua
│       ├── Util.lua
│       └── Core.lua
├── docs/
│   ├── DATA_FORMAT.md
│   ├── DESKTOP_INTEGRATION.md
│   ├── TESTING.md
│   ├── RELEASE_NOTES_1.0.0.md
│   └── RELEASE_NOTES_1.1.1.md
├── BUILD-ADDON.ps1
├── LICENSE
└── README.md
```

## Compatibility

Addon 1.1.1 targets ESO API version `101050` and the current ATTB desktop data contract:

- SavedVariables root schema: **1**
- character snapshot schema: **2**

The desktop parser is intentionally data-only and never evaluates Lua as executable code.

## Development disclosure

Arrow to the Build uses AI-assisted development. Changes are expected to be reviewed against the current ESO API, tested, and kept maintainable rather than accepted simply because generated code appears to work.

## License and disclaimer

The addon source is licensed under the MIT License. See [LICENSE](LICENSE).

Arrow to the Build is an unofficial community project. It is not affiliated with, endorsed by, or sponsored by ZeniMax Media, Bethesda Softworks, or *The Elder Scrolls Online*. Game names, marks, and game assets belong to their respective owners.
