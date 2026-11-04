$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
$out=Join-Path 'reports/gate_selftests' ('coverage_'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Force $out
$rows=@()
function Check([string]$Name,[bool]$Condition){
  if(!$Condition){throw "COVERAGE_FORMAT_TEST: $Name"}
  $script:rows += [pscustomobject]@{name=$Name;result='PASS'}
}
function Reject([string]$Name,[scriptblock]$Action){
  $rejected=$false
  try{& $Action | Out-Null}catch{$rejected=$true}
  Check $Name $rejected
}
$legacy=" Covergroup Bins 3 3 0 1 100.0`n Cover Directives 2 2 0 1 100.0`n Assertions 4 4 0 1 100.0"
$modern=$legacy.Replace('Cover Directives','Directives')
Check 'legacy functional summary accepted' (@(Assert-CoverageTotals $legacy).Count -eq 3)
Check 'modern functional summary accepted' (@(Assert-CoverageTotals $modern).Count -eq 3)
Reject 'modern misses still rejected' { Assert-CoverageTotals ($modern.Replace('3 3 0','3 2 1')) }
Reject 'modern zero bins still rejected' { Assert-CoverageTotals ($modern.Replace('3 3 0','0 0 0')) }
Reject 'duplicate metric alias rejected' { Assert-CoverageTotals ($modern+"`n Cover Directives 2 2 0 1 100.0") }
Reject 'missing assertion row rejected' { Assert-CoverageTotals ($modern -replace '(?m)^ Assertions.*','') }
$policy=Join-Path $out 'policy.psd1'
"@{Gates=@(@{Module='fixture';Metric='Statements';Minimum=95.0},@{Module='fixture';Metric='Branches';Minimum=90.0},@{Module='fixture';Metric='FSM';Minimum=85.0});Waivers=@()}" | Set-Content $policy
function Gate([string]$Name,[string]$Text){
  $path=Join-Path $out ($Name+'.txt')
  $Text | Set-Content $path
  & (Join-Path $PSScriptRoot 'generate_rtl_coverage_gate.ps1') -ByDuReport $path -PolicyPath $policy -OutputDir (Join-Path $out $Name) | Out-Null
  Get-Content -Raw (Join-Path $out "$Name/rtl_coverage_gate.json") | ConvertFrom-Json
}
$header="=== Design Unit: work.fixture`n"
$old=$header+" Stmts 20 19 1 95.0`n Branches 10 9 1 90.0`n FSMs 90.0`n States 3 3 0 100.0`n Transitions 5 4 1 80.0"
$new=$header+" Statements 20 19 1 95.00%`n Branches 10 9 1 90.00%`n FSM States 3 3 0 100.00%`n FSM Transitions 5 4 1 80.00%"
$oldResult=Gate 'legacy' $old
$newResult=Gate 'modern' $new
Check 'legacy and modern RTL gates agree' (($oldResult.gates.Actual -join ',') -eq ($newResult.gates.Actual -join ','))
Check 'FSM preserves equal-weight mean not max or bin-weighted mean' ($newResult.gates[2].Actual -eq 90.0)
Reject 'modern statement miss below original threshold rejected' { Gate 'low-statement' ($new.Replace('20 19 1 95.00','20 18 2 90.00')) }
Reject 'modern FSM miss below original threshold rejected' { Gate 'low-fsm' ($new.Replace('5 4 1 80.00','5 3 2 60.00')) }
Reject 'missing modern transition metric rejected' { Gate 'missing-transition' ($new -replace '(?m)^ FSM Transitions.*','') }
Reject 'inconsistent FSM counts rejected' { Gate 'bad-fsm-counts' ($new.Replace('5 4 1','5 4 0')) }
Write-EvidenceJson (Join-Path $out 'results.json') @{result='PASS';total=$rows.Count;cases=$rows}
Write-Output "Coverage format/gate tests passed: $($rows.Count)/$($rows.Count); $out"
