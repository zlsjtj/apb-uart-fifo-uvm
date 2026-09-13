$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
$dir='reports/gate_selftests'
New-Item -ItemType Directory -Force $dir | Out-Null
$rows=@()
function Check([string]$Name,[bool]$Condition) {
  if (!$Condition) { throw "GATE_SELFTEST_FAILED: $Name" }
  $script:rows += [pscustomobject]@{ name=$Name; result='PASS' }
}
function Rejected([string]$Name,[scriptblock]$Action,[string]$Pattern) {
  $message=''
  try { & $Action | Out-Null } catch { $message=$_.Exception.Message }
  Check $Name ($message -match $Pattern)
}
$pass="# UVM_INFO x(1) @ 1: t [TEST_DONE] done`n# UVM_INFO x(2) @ 1: t [SB_SUMMARY] checked`n# UVM_WARNING : 0`n# UVM_ERROR : 0`n# UVM_FATAL : 0"
Check 'valid completed UVM baseline accepted' (Get-UvmOutcome $pass 0).pass
Check 'empty simulator log rejected' (!(Get-UvmOutcome '' 0).pass)
Check 'simulator warning rejected' (!(Get-UvmOutcome ($pass+"`n# ** Warning: incomplete port connection") 0).pass)
Check 'missing completion marker rejected' (!(Get-UvmOutcome 'UVM_ERROR : 0' 0).pass)
$matching=$pass+"`n# UVM_ERROR x(3) @ 2: t [TARGET] mismatch"
Check 'matching UVM failure killed' ((Get-MutationOutcome $pass 0 $matching 0 'TARGET').result -eq 'KILLED')
$unrelated=$pass+"`n# UVM_INFO x(3) @ 2: t [TARGET] diagnostic`n# UVM_ERROR x(4) @ 3: t [UNRELATED] mismatch"
Check 'INFO detector plus unrelated error is not killed' ((Get-MutationOutcome $pass 0 $unrelated 0 'TARGET').result -eq 'SURVIVED')
$assertion=$pass+"`n# ** Error: Assertion error.`n# Time: 2 ns Started: 2 ns Scope: tb.TARGET File: rtl/test.sv Line: 1"
Check 'assertion continuation belongs to failure record' ((Get-MutationOutcome $pass 0 $assertion 0 'TARGET').result -eq 'KILLED')
Check 'failed baseline invalidates mutation' ((Get-MutationOutcome $matching 0 $matching 0 'TARGET').result -eq 'INVALID_BASELINE')
Check 'simulator exit failure is not a killed mutant' ((Get-MutationOutcome $pass 0 $matching 1 'TARGET').result -eq 'INVALID_RUN')
Check 'timeout is not a killed mutant' ((Get-MutationOutcome $pass 0 ($matching+"`n# UVM_FATAL x(4) @ 3: t [TIMEOUT] stopped") 0 'TARGET').result -eq 'INVALID_RUN')
$coverage=" Covergroup Bins 3 3 0 1 100.0`n Cover Directives 2 2 0 1 100.0`n Assertions 4 4 0 1 100.0"
Check 'complete functional and assertion coverage accepted' (@(Assert-CoverageTotals $coverage).Count -eq 3)
Rejected 'coverage misses rejected' { Assert-CoverageTotals ($coverage.Replace('3 3 0','3 2 1')) } 'COVERAGE_INCOMPLETE'
Rejected 'missing coverage metric rejected' { Assert-CoverageTotals 'Covergroup Bins 3 3 0 1 100.0' } 'COVERAGE_MISSING'

$summary=Join-Path $dir 'missing_ucdb.md'
'| uart_nonexistent_fixture_test | 987654 | PASS | 0 | 0 | 0 |' | Set-Content $summary
Rejected 'missing UCDB refused by actual merge script' {
  & (Join-Path $PSScriptRoot 'merge_coverage.ps1') -SummaryPath $summary -OutputDir (Join-Path $dir 'coverage')
} 'Coverage database.*missing'

$badCdc=Join-Path $dir 'bad_cdc.rpt'
"CDC-1 Critical 1 unknown`n  1  CDC-1  Critical  unknown  0  None  bad/source/C  bad/dest/D" | Set-Content $badCdc
Rejected 'unreviewed Critical refused by actual CDC checker' {
  & (Join-Path $PSScriptRoot 'check_cdc_paths.ps1') -Report $badCdc -Output (Join-Path $dir 'cdc.json')
} 'CDC_PATH_REVIEW_FAILED'
"CDC-15 Warning 1 unknown`n  1  CDC-15  Warning  unknown  0  None  bad/source/C  bad/dest/D" | Set-Content $badCdc
Rejected 'unknown Warning endpoint refused' {
  & (Join-Path $PSScriptRoot 'check_cdc_paths.ps1') -Report $badCdc -Output (Join-Path $dir 'cdc.json')
} 'CDC_PATH_REVIEW_FAILED'

$sourceRoot=[IO.Path]::GetFullPath((Join-Path $dir 'source_fixture'))
New-Item -ItemType Directory -Force (Join-Path $sourceRoot 'rtl') | Out-Null
'' | Set-Content (Join-Path $sourceRoot 'filelist.f')
'' | Set-Content (Join-Path $sourceRoot 'rtl_filelist.f')
'module fixture; endmodule' | Set-Content (Join-Path $sourceRoot 'rtl/fixture.sv')
$identity=Get-SourceIdentity $sourceRoot
'module changed; endmodule' | Set-Content (Join-Path $sourceRoot 'rtl/fixture.sv')
Rejected 'changed source hash refused' { Assert-SourceIdentity $identity $sourceRoot } 'SOURCE_DRIFT'

$failedSummary=Join-Path $dir 'acceptance_summary.json'
Write-EvidenceJson $failedSummary @{ result='PASS'; runId='stale_fixture' }
Rejected 'acceptance injected failure throws' {
  & (Join-Path $PSScriptRoot 'run_acceptance.ps1') -SummaryPath $failedSummary -InjectFailureAfterSetup
} 'INJECTED_ACCEPTANCE_FAILURE'
$failed=Get-Content -Raw $failedSummary | ConvertFrom-Json
Check 'old PASS replaced by fresh FAIL' ($failed.result -eq 'FAIL' -and $failed.runId -ne 'stale_fixture')
Write-EvidenceJson 'reports/evidence_gate_selftests.json' @{ result='PASS'; total=$rows.Count; cases=$rows }
$global:LASTEXITCODE=0
Write-Host "Evidence negative self-tests passed: $($rows.Count)/$($rows.Count)"
