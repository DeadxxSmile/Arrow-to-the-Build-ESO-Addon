[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Join-Path $root "addon"
$mainDir = Join-Path $addonRoot "ArrowToTheBuild"
$mainManifest = Join-Path $mainDir "ArrowToTheBuild.txt"

function Get-ManifestField([string]$Path, [string]$Field) {
    $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match "^## $([regex]::Escape($Field)):\s*(.+)$" } | Select-Object -First 1
    if (-not $line) { throw "Missing '$Field' in $Path" }
    return ($line -replace "^## $([regex]::Escape($Field)):\s*", "").Trim()
}

foreach ($path in @($mainDir, $mainManifest)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required addon source is missing: $path" }
}

$version = Get-ManifestField $mainManifest "Version"
$apiVersion = Get-ManifestField $mainManifest "APIVersion"
$numericVersion = Get-ManifestField $mainManifest "AddOnVersion"
$savedVariables = Get-ManifestField $mainManifest "SavedVariables"

if ($savedVariables -ne "ArrowToTheBuildSavedVariables") {
    throw "Unexpected SavedVariables root: $savedVariables"
}

if (Test-Path -LiteralPath (Join-Path $addonRoot "ArrowToTheBuildBridge")) {
    throw "Retired ArrowToTheBuildBridge source is still present. Remove it before packaging."
}

$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$zip = Join-Path $output "ATTB_v$version.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

Compress-Archive -LiteralPath $mainDir -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Arrow to the Build ESO Addon" -ForegroundColor Cyan
Write-Host "Version:      $version"
Write-Host "APIVersion:   $apiVersion"
Write-Host "AddOnVersion: $numericVersion"
Write-Host "Built:        $zip" -ForegroundColor Green
