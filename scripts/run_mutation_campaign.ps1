param([string]$PlanPath='config/mutation_plan.psd1', [string]$Filelist='filelist.f', [string[]]$CaseIds=@(),
      [string]$TestOverride='', [Nullable[int]]$SeedOverride=$null,
      [ValidateSet('fixed','expanded')][string]$SeedMode='fixed',[int]$CampaignSeed=0)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain
Write-EvidenceJson 'reports/mutation_campaign.json' @{ result='RUNNING'; phase='validate_plan' }
$cases=@((Import-PowerShellDataFile $PlanPath).Cases)
foreach ($key in @('Id','Define')) {
  if (@($cases | ForEach-Object { $_[$key] } | Select-Object -Unique).Count -ne $cases.Count) { throw "Duplicate mutation $key" }
}
foreach ($c in $cases) {
  if ($c.Id -notmatch '^[a-z0-9_]+$' -or $c.Define -notmatch '^UART_MUTATE_[A-Z0-9_]+$' -or
      $c.Test -notmatch '^uart_\w+_test$' -or !$c.Detector) { throw 'Invalid mutation declaration' }
}
if ($CaseIds.Count) {
  foreach ($id in $CaseIds) { if ($id -notin $cases.Id) { throw "Unknown mutation $id" } }
  $cases=@($cases | Where-Object { $_.Id -in $CaseIds })
}
if ($TestOverride -or $null -ne $SeedOverride) {
  if ($cases.Count -ne 1) { throw 'Overrides require exactly one selected mutation' }
  if ($TestOverride) {
    if ($TestOverride -notmatch '^uart_\w+_test$') { throw 'Invalid test override' }
    $cases[0].Test=$TestOverride
  }
  if ($null -ne $SeedOverride) { $cases[0].Seed=[int]$SeedOverride }
}
foreach ($case in $cases) { $case.Seed=Get-CampaignSeed $case.Seed $SeedMode $CampaignSeed }
New-Item -ItemType Directory -Force logs,reports | Out-Null
$identity=Get-SourceIdentity
$state=[ordered]@{ generatedAt=(Get-Date -Format o); result='RUNNING'; killed=0; total=$cases.Count; source=$identity; cases=@(); seedMode=$SeedMode;campaignSeed=$CampaignSeed;
  boundary='Only declared fault models. Each killed case requires a passing same-test/same-seed baseline and a matching failure record; tool errors and timeouts are invalid runs.' }
Write-EvidenceJson 'reports/mutation_campaign.json' $state
function Compile-Library([string]$Library,[string]$Define='') {
  if (!(Test-Path $Library)) { & vlib $Library | Out-Null; if ($LASTEXITCODE) { throw "vlib failed: $Library" } }
  $args=@('-work',$Library,'-sv','-assertdebug','+acc')
  if ($Define) { $args += "+define+$Define" }
  & vlog @args -f $Filelist -l ("logs/" + $Library + "_compile.log") | Out-Null
  if ($LASTEXITCODE) { throw "Compile failed: $Library" }
}
function Simulate([string]$Library,$Case,[string]$Log) {
  & vsim -c "$Library.tb_apb_uart" "+UVM_TESTNAME=$($Case.Test)" '+PCLK_HALF_NS=5' '+UART_HALF_NS=20' '+PCLK_PHASE_NS=0' '+UART_PHASE_NS=0' -sv_seed $Case.Seed -assertdebug -do 'run -all; quit -f' -l $Log | Out-Null
  [pscustomobject]@{ exitCode=$LASTEXITCODE; text=(Get-Content -Raw $Log) }
}
try {
  Compile-Library 'work_mut_baseline'
  foreach ($case in $cases) {
    Write-Host "[MUTATION] $($case.Id): baseline + mutant"
    $baseLog="logs/mutation_$($case.Id)_baseline_$($case.Seed).log"
    $mutLog="logs/mutation_$($case.Id)_$($case.Seed).log"
    $base=Simulate 'work_mut_baseline' $case $baseLog
    $lib="work_mut_$($case.Id)"
    Compile-Library $lib $case.Define
    $mut=Simulate $lib $case $mutLog
    $outcome=Get-MutationOutcome $base.text $base.exitCode $mut.text $mut.exitCode $case.Detector
    $state.cases += [pscustomobject]@{ id=$case.Id; name=$case.Name; define=$case.Define; test=$case.Test; seed=$case.Seed;
      result=$outcome.result; baselinePass=$outcome.baselinePass; detector=$case.Detector; matchedFailureLines=$outcome.matchedFailureLines;
      baselineLog=$baseLog; log=$mutLog; simulatorExit=$mut.exitCode }
    $state.killed=@($state.cases | Where-Object result -eq 'KILLED').Count
    Write-EvidenceJson 'reports/mutation_campaign.json' $state
  }
  Assert-SourceIdentity $identity
  if ($state.killed -ne $cases.Count) { throw 'Some mutations survived or had invalid baselines/runs' }
  $state.result='PASS'
} catch {
  $state.result='FAIL'; $state.error=$_.Exception.Message
  throw
} finally {
  Write-EvidenceJson 'reports/mutation_campaign.json' $state
  $summary=@('# Mutation Campaign','',"- Result: $($state.result)","- Killed: $($state.killed)/$($state.total)",'',
    '| Case | Baseline | Result | Matched failure |','| --- | --- | --- | --- |')
  foreach ($row in $state.cases) { $summary += "| $($row.id) | $($row.baselinePass) | $($row.result) | $($row.matchedFailureLines.Count) record(s) |" }
  $summary | Set-Content -Encoding UTF8 reports/mutation_campaign.md
}
Write-Host "Mutation campaign passed: $($state.killed)/$($state.total)"
