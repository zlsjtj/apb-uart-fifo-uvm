param([Parameter(Mandatory)][string]$RunId,[string]$OutputRoot='deliveries',[switch]$NoPublish)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/delivery_common.ps1"
$root=[IO.Path]::GetFullPath((Get-Location).Path)
if ($RunId -notmatch '^\d{8}_\d{6}_[a-f0-9]{8}$') { throw 'DELIVERY_RUN_ID: invalid run ID' }
$runDir=Resolve-ContainedPath $root "reports/acceptance_runs/$RunId"
$snapshot=Resolve-ContainedPath $runDir 'workspace'
$summary=Get-Content -Raw -LiteralPath (Join-Path $runDir 'acceptance_summary.json') | ConvertFrom-Json
if ($summary.runId -ne $RunId) { throw 'DELIVERY_RUN_ID: summary mismatch' }
Assert-AcceptanceRun $summary $snapshot
$out=Resolve-ContainedPath $root $OutputRoot
$final=Resolve-ContainedPath $out $RunId
if (Test-Path -LiteralPath $final) { throw 'DELIVERY_EXISTS: immutable destination already exists' }
$staging=Resolve-ContainedPath $out ('.staging_'+$RunId+'_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging -Force | Out-Null
foreach ($dir in @('rtl','tb','scripts','config','constraints','docs','logs')) {
  $source=Resolve-ContainedPath $snapshot $dir
  $null=Get-DeliveryFiles $source
  Copy-Item -LiteralPath $source -Destination $staging -Recurse
}
foreach ($file in @('README.md','filelist.f','rtl_filelist.f')) { Copy-Item -LiteralPath (Join-Path $snapshot $file) -Destination $staging }
New-Item -ItemType Directory -Path (Join-Path $staging 'reports') | Out-Null
foreach ($item in Get-ChildItem -LiteralPath (Join-Path $snapshot 'reports')) {
  if ($item.Name -in @('acceptance_runs','gate_selftests','workflow_selftests')) { continue }
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'DELIVERY_PATH: reparse point refused' }
  if ($item.PSIsContainer) { $null=Get-DeliveryFiles $item.FullName }
  Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $staging 'reports') -Recurse
}
New-Item -ItemType Directory -Path (Join-Path $staging 'acceptance') | Out-Null
Copy-Item -LiteralPath (Join-Path $runDir 'acceptance_summary.json') -Destination (Join-Path $staging 'acceptance/original_summary.json')
$index=0
foreach ($step in $summary.steps) {
  $index++; $log="step_$index.log"
  Copy-Item -LiteralPath (Join-Path $runDir $log) -Destination (Join-Path $staging "acceptance/$log")
  $step.log="acceptance/$log"
}
$summary.snapshot='.'; $summary.runDirectory='.'
Write-EvidenceJson (Join-Path $staging 'acceptance_summary.json') $summary
New-PaperResults $staging $summary
Assert-AcceptanceRun $summary $staging
$files=@(Get-DeliveryFiles $staging)
Write-EvidenceJson (Join-Path $staging 'delivery_manifest.json') @{schemaVersion=1;result='PASS';runId=$RunId;sourceSha256=$summary.source.sha256;files=$files}
$manifest=Assert-Delivery $staging
# Both paths are resolved and checked inside the selected workspace before rename.
Move-Item -LiteralPath $staging -Destination $final
$null=Assert-Delivery $final
if (!$NoPublish) {
  $published=Resolve-ContainedPath $root "reports/published/$RunId"
  if (Test-Path -LiteralPath $published) { throw 'DELIVERY_EXISTS: published run already exists' }
  New-Item -ItemType Directory -Path $published -Force | Out-Null
  foreach ($file in @('delivery_manifest.json','acceptance_summary.json','paper_results.md')) { Copy-Item -LiteralPath (Join-Path $final $file) -Destination $published }
  Copy-Item -LiteralPath (Join-Path $final 'reports/runtime_manifest.json') -Destination $published
  foreach ($relative in @('final_regression/final_regression_summary.json','parameter_regression/summary.json','fifo_unit_tests.json',
    'mutation_campaign.json','final_regression/coverage/functional_assertion_gate.json','final_regression/coverage/rtl_coverage_gate.json','synthesis/cdc_review.json')) {
    $dest=Join-Path $published "reports/$relative"
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $final "reports/$relative") -Destination $dest
  }
  Write-EvidenceJson (Join-Path $root 'reports/published/latest.json') @{result='PASS';runId=$RunId;sourceSha256=$manifest.sourceSha256;
    bundle="$OutputRoot/$RunId";summary="$RunId/acceptance_summary.json";paperResults="$RunId/paper_results.md";
    manifest="$RunId/delivery_manifest.json";manifestSha256=(Get-FileHash -LiteralPath (Join-Path $final 'delivery_manifest.json') -Algorithm SHA256).Hash}
}
Write-Host "Delivery exported and verified: $final ($($files.Count) files)"
