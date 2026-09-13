param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/delivery_common.ps1"
$manifest=Assert-Delivery ([IO.Path]::GetFullPath($Path))
Write-Host "Delivery verified: $($manifest.runId), $($manifest.files.Count) files, source $($manifest.sourceSha256)"
