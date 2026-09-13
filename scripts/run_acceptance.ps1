param(
  [int[]]$Seeds=@(101,201,301),
  [string]$PlanPath='config/verification_plan.psd1',
  [string]$SummaryPath='reports/acceptance_summary.json',
  [ValidateSet('fixed','expanded')][string]$SeedMode='fixed',
  [int]$CampaignSeed=0,
  [string]$ToolConfigPath='',
  [switch]$InjectFailureAfterSetup
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. (Join-Path $PSScriptRoot 'toolchain_common.ps1')
$root=(Get-Location).Path
$started=Get-Date
$runId=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runDir=Join-Path $root "reports/acceptance_runs/$runId"
$snapshot=Join-Path $runDir 'workspace'
$latest=[IO.Path]::GetFullPath((Join-Path $root $SummaryPath))
if (!$latest.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Summary path escapes workspace' }
$state=[ordered]@{ runId=$runId; startedAt=$started.ToString('o'); result='RUNNING'; seeds=$Seeds; runDirectory=$runDir;
  snapshot=$snapshot; steps=@(); elapsedSeconds=0; baselineCommit=''; source=$null; error=$null;
  seedMode=$SeedMode;campaignSeed=$CampaignSeed;runtime=$null }
function Save-State {
  $state.elapsedSeconds=[math]::Round(((Get-Date)-$started).TotalSeconds,1)
  Write-EvidenceJson $latest $state
  Write-EvidenceJson (Join-Path $runDir 'acceptance_summary.json') $state
}
Save-State
$pwsh=(Get-Process -Id $PID).Path
function Run-Step([string]$Name,[string]$Command) {
  $index=$state.steps.Count+1
  $log=Join-Path $runDir ("step_"+$index+".log")
  $row=[pscustomobject]@{ name=$Name; result='RUNNING'; command=$Command; log=$log; startedAt=(Get-Date -Format o) }
  $state.steps+= $row
  Save-State
  Write-Host "[ACCEPTANCE $runId] $Name"
  Push-Location $snapshot
  try {
    & $pwsh -NoProfile -Command $Command > $log 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Step failed ($LASTEXITCODE): $Name; $log" }
    $row.result='PASS'
  } catch { $row.result='FAIL'; throw }
  finally { Pop-Location; Save-State }
}
try {
  if ($InjectFailureAfterSetup) { throw 'INJECTED_ACCEPTANCE_FAILURE: negative self-test' }
  $null=Get-CampaignSeed 1 $SeedMode $CampaignSeed
  $state.runtime=Initialize-Toolchain $ToolConfigPath
  if ($Seeds.Count -lt 3 -or @($Seeds | Select-Object -Unique).Count -ne $Seeds.Count) { throw 'Acceptance requires at least three unique base seeds' }
  if ($PlanPath -notmatch '^config/[a-zA-Z0-9_/-]+\.psd1$' -or $PlanPath.Contains('..')) { throw 'Invalid plan path' }
  $plan=Import-PowerShellDataFile $PlanPath
  if (@($plan.StressProfiles).Count -lt 2) { throw 'At least two stress profiles required' }
  $state.source=Get-SourceIdentity $root
  $savedGit=$env:GIT_CONFIG_GLOBAL
  try { $env:GIT_CONFIG_GLOBAL='NUL'; $state.baselineCommit=(& git rev-parse HEAD).Trim() }
  finally { $env:GIT_CONFIG_GLOBAL=$savedGit }
  New-Item -ItemType Directory -Force $snapshot | Out-Null
  foreach ($dir in @('rtl','tb','scripts','config','constraints','docs')) {
    Copy-Item -LiteralPath (Join-Path $root $dir) -Destination $snapshot -Recurse
  }
  foreach ($file in @('filelist.f','rtl_filelist.f','README.md')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $snapshot
  }
  Assert-SourceIdentity $state.source $snapshot
  Save-State
  Run-Step 'Toolchain and license preflight' '& ./scripts/run_toolchain_preflight.ps1'
  Run-Step 'Workflow integrity self-tests' '& ./scripts/test_workflow.ps1'
  Run-Step 'Gate negative self-tests' '& ./scripts/test_evidence_gates.ps1'
  Run-Step 'RTL lint and structural CDC/RDC' '& ./scripts/run_static_checks.ps1'
  Run-Step 'APB completion-edge and FIFO parameter contract' '& ./scripts/run_contract_tests.ps1'
  Run-Step 'Independent randomized FIFO unit checks' "& ./scripts/run_fifo_unit_tests.ps1 -Seed $($Seeds[0]+4000)"
  Run-Step 'OOC synthesis, timing and CDC path classification' '& ./scripts/run_vivado_synth.ps1'
  $seedText='@('+($Seeds -join ',')+')'
  Run-Step 'Three-seed regression and coverage gates' "& ./scripts/run_final_regression.ps1 -Seeds $seedText -PlanPath '$PlanPath'"
  Run-Step 'Parameterized UVM and no-probe checks' "& ./scripts/run_parameter_regression.ps1 -Seed $($Seeds[0]+5000) -PlanPath '$PlanPath'"
  foreach ($profile in $plan.StressProfiles) {
    if ($profile.Name -notmatch '^[a-zA-Z0-9_]+$') { throw 'Invalid stress name' }
    foreach ($test in $profile.Tests) {
      if ($test -notmatch '^uart_\w+_test$') { throw 'Invalid stress test name' }
    }
    $testText='@('+((@($profile.Tests) | ForEach-Object { "'$_'" }) -join ',')+')'
    $stressSeed=Get-CampaignSeed $profile.Seed $SeedMode $CampaignSeed
    $cmd="& ./scripts/run_questa.ps1 -Tests $testText -Seed $stressSeed -PclkHalfNs $($profile.PclkHalfNs) -UartHalfNs $($profile.UartHalfNs) -PclkPhaseNs $($profile.PclkPhaseNs) -UartPhaseNs $($profile.UartPhaseNs)"
    Run-Step ("Stress "+$profile.Name) $cmd
    $stress=Join-Path $snapshot ("reports/stress/"+$profile.Name)
    New-Item -ItemType Directory -Force $stress | Out-Null
    Copy-Item -LiteralPath (Join-Path $snapshot 'reports/regression_summary.md') -Destination $stress
    Copy-Item -LiteralPath (Join-Path $snapshot 'reports/regression_summary.json') -Destination $stress
  }
  Run-Step 'Same-seed baseline controlled mutation campaign' "& ./scripts/run_mutation_campaign.ps1 -SeedMode '$SeedMode' -CampaignSeed $CampaignSeed"
  Assert-SourceIdentity $state.source $snapshot
  Assert-SourceIdentity $state.source $root
  $state.result='PASS'
} catch {
  $state.result='FAIL'
  $state.error=$_.Exception.Message
} finally {
  $state.elapsedSeconds=[math]::Round(((Get-Date)-$started).TotalSeconds,1)
  Save-State
  $md=@('# Acceptance Summary','',"- Run: $runId","- Result: $($state.result)","- Baseline commit (not the modified source identity): $($state.baselineCommit)",
    "- Evidence: $runDir", "- Elapsed seconds: $($state.elapsedSeconds)",'','| Step | Result |','| --- | --- |')
  foreach ($step in $state.steps) { $md += "| $($step.name) | $($step.result) |" }
  if ($state.error) { $md += ''; $md += $state.error }
  $md | Set-Content -Encoding UTF8 ([IO.Path]::ChangeExtension($latest,'.md'))
}
if ($state.result -ne 'PASS') { throw $state.error }
Write-Host "Acceptance passed: $($state.steps.Count)/$($state.steps.Count); $runDir"
