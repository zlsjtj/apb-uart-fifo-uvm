param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$EvidenceRoot = (Join-Path $PSScriptRoot 'historical'),
    [string]$OutputRoot = ''
)
$ErrorActionPreference = 'Stop'
$out = if ($OutputRoot) { $OutputRoot } else { Join-Path $RepoRoot 'work_runner_selftest' }
$project = Join-Path $out ('project-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force (Join-Path $project 'scripts'), (Join-Path $project 'config')
foreach ($name in @('run_apb_regblock.ps1','toolchain_common.ps1')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts/$name") -Destination (Join-Path $project 'scripts')
}
Copy-Item -LiteralPath (Join-Path $RepoRoot 'config/toolchain.psd1') -Destination (Join-Path $project 'config')
$logs = @{}
foreach ($mode in @('baseline','fault')) {
    $text = Get-Content -Raw (Join-Path $EvidenceRoot "apb-uvm-$mode.txt")
    $text = $text -replace '(?m)^UVM_WARNING\s+[^\r\n]*\[[^\]]+\][^\r\n]*\r?\n', ''
    $text = $text -replace '(?m)^UVM_WARNING\s*:\s*2\s*$', 'UVM_WARNING : 0'
    $logs[$mode] = (($text -split '\r?\n' | ForEach-Object { '# ' + $_ }) -join "`n")
}
function vlib { $global:LASTEXITCODE = 0 }
function vlog { $global:LASTEXITCODE = $global:pr1CompileExit }
function vsim {
    $global:pr1SimCalled = $true
    $arguments = @($args)
    $log = $arguments[[array]::IndexOf($arguments, '-l') + 1]
    if ($global:pr1WriteLog) { [IO.File]::WriteAllText((Join-Path (Get-Location) $log), $global:pr1Fixture) }
    $global:LASTEXITCODE = $global:pr1SimExit
}
$license = '# ** Error: Failure to obtain a Verilog simulation license. Unable to checkout qhsimvl or msimhdlsim'
$cases = @(
    @{name='baseline';fault=$false;log=$logs.baseline;exit=0;compile=0;write=$true;pass=$true;marker='PASS: 12 monitored'},
    @{name='specified-fault';fault=$true;log=$logs.fault;exit=0;compile=0;write=$true;pass=$true;marker='EXPECTED_FAULT_DETECTED'},
    @{name='license-failure-exit-zero';fault=$true;log=$license;exit=0;compile=0;write=$true;pass=$false},
    @{name='nonzero-exit-with-valid-log';fault=$true;log=$logs.fault;exit=1;compile=0;write=$true;pass=$false},
    @{name='no-log-created';fault=$true;log='';exit=0;compile=0;write=$false;pass=$false},
    @{name='empty-log';fault=$true;log='';exit=0;compile=0;write=$true;pass=$false},
    @{name='stale-log-not-rewritten';fault=$true;log='';exit=0;compile=0;write=$false;pass=$false;stale=$logs.fault},
    @{name='compile-failure-with-stale-log';fault=$true;log='';exit=0;compile=1;write=$false;pass=$false;stale=$logs.fault},
    @{name='baseline-as-fault';fault=$true;log=$logs.baseline;exit=0;compile=0;write=$true;pass=$false},
    @{name='fault-as-baseline';fault=$false;log=$logs.fault;exit=0;compile=0;write=$true;pass=$false}
)
$results = @()
foreach ($case in $cases) {
    $global:pr1Fixture = $case.log
    $global:pr1WriteLog = $case.write
    $global:pr1CompileExit = $case.compile
    $global:pr1SimExit = $case.exit
    $global:pr1SimCalled = $false
    $mode = if ($case.fault) { 'fault' } else { 'baseline' }
    $log = Join-Path $project "logs/apb-regblock/${mode}_1702/run.log"
    if ($case.stale) {
        $null = New-Item -ItemType Directory -Force (Split-Path $log)
        [IO.File]::WriteAllText($log, $case.stale)
    }
    $accepted = $false
    $message = ''
    try {
        $output = (& (Join-Path $project 'scripts/run_apb_regblock.ps1') -Seed 1702 -InjectFault:($case.fault) 6>&1 | Out-String)
        $accepted = $true
        $message = $output.Trim()
    } catch { $message = $_.Exception.Message }
    if ($accepted -ne $case.pass) { throw "Unexpected outcome for $($case.name): $message" }
    if ($case.pass -and $message -notlike "*$($case.marker)*") { throw "Missing result marker for $($case.name)" }
    if ($case.compile -ne 0 -and $global:pr1SimCalled) { throw 'Simulation was called after compile failure' }
    $results += [pscustomobject]@{case=$case.name;accepted=$accepted;simulatorMockCalled=$global:pr1SimCalled;message=$message}
    Write-Output "PASS: $($case.name), accepted=$accepted"
}
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $out 'results.json') -Encoding UTF8
Write-Output 'Mocked process lifecycle checks only; these fixtures are not simulation results.'
