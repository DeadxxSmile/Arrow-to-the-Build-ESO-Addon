-- Arrow to the Build - ESO character snapshot exporter.

ArrowToTheBuild = ArrowToTheBuild or {}
local ATTB = ArrowToTheBuild

ATTB.name = "ArrowToTheBuild"
ATTB.displayName = "Arrow to the Build"
ATTB.version = "1.1.1"
ATTB.savedVariablesSchemaVersion = 1
ATTB.snapshotSchemaVersion = 2
ATTB.snapshotDataProfile = "compact"
ATTB.debounceMilliseconds = 1200
ATTB.minimumAutomaticCaptureIntervalSeconds = 15
ATTB.updateRegistrationName = "ArrowToTheBuildSnapshotDebounce"
ATTB.eventNamespacePrefix = "ArrowToTheBuild_"
ATTB.slashCommandExport = "/attbexport"
ATTB.slashCommandStatus = "/attbstatus"
ATTB.slashCommandCharacters = "/attbcharacters"

ATTB.Collectors = ATTB.Collectors or {}
ATTB.Util = ATTB.Util or {}
ATTB.runtime = ATTB.runtime or {
    initialized = false,
    eventsRegistered = false,
    pendingReasons = {},
    pendingSections = {},
    pendingForceFull = false,
    pendingBypassCooldown = false,
    lastSnapshotAt = 0,
    lastAutomaticCaptureAt = 0,
}
