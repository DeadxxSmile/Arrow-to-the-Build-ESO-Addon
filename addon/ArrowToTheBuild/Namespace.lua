-- Arrow to the Build - ESO Companion Addon
-- Silent character snapshot exporter for the ATTB desktop app.

ArrowToTheBuild = ArrowToTheBuild or {}
local ATTB = ArrowToTheBuild

ATTB.name = "ArrowToTheBuild"
ATTB.displayName = "Arrow to the Build"
ATTB.version = "1.0.0"
ATTB.savedVariablesSchemaVersion = 1
ATTB.snapshotSchemaVersion = 2
ATTB.snapshotDataProfile = "compact"
ATTB.debounceMilliseconds = 2500
ATTB.minimumAutomaticCaptureIntervalSeconds = 30
ATTB.minimumPrioritySaveIntervalSeconds = 900
ATTB.updateRegistrationName = "ArrowToTheBuildSnapshotDebounce"
ATTB.eventNamespacePrefix = "ArrowToTheBuildEvent_"
ATTB.slashCommandExport = "/attbexport"
ATTB.slashCommandStatus = "/attbstatus"
ATTB.slashCommandCharacters = "/attbcharacters"

ATTB.Collectors = ATTB.Collectors or {}
ATTB.Schema = ATTB.Schema or {}
ATTB.Util = ATTB.Util or {}
ATTB.runtime = ATTB.runtime or {
    initialized = false,
    playerActivated = false,
    eventListenersRegistered = false,
    pendingReasons = {},
    pendingSections = {},
    pendingForceFull = false,
    pendingBypassCooldown = false,
    lastSnapshotAt = 0,
    lastAutomaticCaptureAt = 0,
    lastPrioritySaveRequestAt = 0,
    currentDiagnostics = nil,
    savedRootPresentAtLoad = false,
    loadedCharacterCount = 0,
    loadedRevision = 0,
    loadedAddonVersion = "none",
    loadedSchemaVersion = 0,
    loadedCreatedAt = 0,
    migratedCharacterCount = 0,
    lastCaptureSections = {},
    lastBridgePublishStatus = "not-installed",
}
