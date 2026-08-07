[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Join-Path $root "addon"
$mainDir = Join-Path $addonRoot "ArrowToTheBuild"
$bridgeDir = Join-Path $addonRoot "ArrowToTheBuildBridge"
$mainManifest = Join-Path $mainDir "ArrowToTheBuild.txt"
$bridgeManifest = Join-Path $bridgeDir "ArrowToTheBuildBridge.txt"

function Get-ManifestField([string]$Path, [string]$Field) {
    $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match "^## $([regex]::Escape($Field)):\s*(.+)$" } | Select-Object -First 1
    if (-not $line) { throw "Missing '$Field' in $Path" }
    return ($line -replace "^## $([regex]::Escape($Field)):\s*", "").Trim()
}

foreach ($path in @($mainDir, $bridgeDir, $mainManifest, $bridgeManifest)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required addon source is missing: $path" }
}

$mainVersion = Get-ManifestField $mainManifest "Version"
$bridgeVersion = Get-ManifestField $bridgeManifest "Version"
$mainApi = Get-ManifestField $mainManifest "APIVersion"
$bridgeApi = Get-ManifestField $bridgeManifest "APIVersion"
$mainNumeric = Get-ManifestField $mainManifest "AddOnVersion"
$bridgeNumeric = Get-ManifestField $bridgeManifest "AddOnVersion"
$bridgeDependency = Get-ManifestField $bridgeManifest "DependsOn"

if ($mainVersion -ne $bridgeVersion) { throw "Addon versions differ: $mainVersion vs $bridgeVersion" }
if ($mainApi -ne $bridgeApi) { throw "APIVersion differs: $mainApi vs $bridgeApi" }
if ($mainNumeric -ne $bridgeNumeric) { throw "AddOnVersion differs: $mainNumeric vs $bridgeNumeric" }
if ($bridgeDependency -ne "ArrowToTheBuild") { throw "Sync Bridge must depend on ArrowToTheBuild." }

$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$zip = Join-Path $output "ATTB-ESOAddon-Built-v$mainVersion.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

Compress-Archive -LiteralPath $mainDir, $bridgeDir -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Arrow to the Build ESO Companion Addon" -ForegroundColor Cyan
Write-Host "Version:      $mainVersion"
Write-Host "APIVersion:   $mainApi"
Write-Host "AddOnVersion: $mainNumeric"
Write-Host "Built:        $zip" -ForegroundColor Green
