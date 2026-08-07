-- Arrow to the Build - ESO Companion Addon
-- Silent character snapshot exporter for the ATTB desktop app.

ArrowToTheBuild = ArrowToTheBuild or {}
local ATTB = ArrowToTheBuild

ATTB.name = "ArrowToTheBuild"
ATTB.displayName = "Arrow to the Build"
ATTB.version = "0.1.0-alpha.3"
ATTB.savedVariablesSchemaVersion = 1
ATTB.snapshotSchemaVersion = 1
ATTB.debounceMilliseconds = 1500
ATTB.minimumPrioritySaveIntervalSeconds = 900
ATTB.updateRegistrationName = "ArrowToTheBuildSnapshotDebounce"
ATTB.eventNamespacePrefix = "ArrowToTheBuildEvent_"
ATTB.slashCommandExport = "/attbexport"
ATTB.slashCommandStatus = "/attbstatus"

ATTB.Collectors = ATTB.Collectors or {}
ATTB.Util = ATTB.Util or {}
ATTB.runtime = ATTB.runtime or {
    initialized = false,
    playerActivated = false,
    eventListenersRegistered = false,
    pendingReason = nil,
    lastSnapshotAt = 0,
    lastPrioritySaveRequestAt = 0,
    currentDiagnostics = nil,
    loadedCharacterCount = 0,
}
