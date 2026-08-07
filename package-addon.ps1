$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonFolder = Join-Path $RepoRoot "addon\ArrowToTheBuild"
$Output = Join-Path $RepoRoot "ArrowToTheBuild-0.1.0-alpha.3.zip"
$Staging = Join-Path $env:TEMP "ArrowToTheBuild-package"

Remove-Item $Staging -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Output -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $Staging | Out-Null
Copy-Item $AddonFolder -Destination $Staging -Recurse
Compress-Archive -Path (Join-Path $Staging "ArrowToTheBuild") -DestinationPath $Output -CompressionLevel Optimal
Remove-Item $Staging -Recurse -Force

Write-Host "Created $Output"
