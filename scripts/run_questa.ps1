param(
  [string[]]$Tests = @(),
  [string]$PlanPath = "config/verification_plan.psd1",
  [int]$Seed = 1,
  [string]$Top = "tb_apb_uart",
  [string]$Filelist = "filelist.f",
  [int]$PclkHalfNs = 5,
  [int]$UartHalfNs = 20,
  [int]$PclkPhaseNs = 0,
  [int]$UartPhaseNs = 0,
  [ValidateRange(1,16)][int]$FifoAddrWidth = 4,
  [switch]$NoWhitebox,
  [switch]$DumpLoopbackVcd
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain
$sourceIdentity = Get-SourceIdentity
Write-EvidenceJson 'reports/regression_summary.json' @{ result='RUNNING'; source=$sourceIdentity }

if (-not (Test-Path $PlanPath)) {
  throw "Verification plan '$PlanPath' was not found."
}
$verificationPlan = Import-PowerShellDataFile $PlanPath
if ($Tests.Count -eq 0) {
  $Tests = @($verificationPlan.RegressionTests)
}
if ($Tests.Count -eq 0) {
  throw "No tests were selected."
}

function Require-Tool($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required tool '$Name' was not found in PATH."
  }
}

function Parse-UvmLog($LogPath) {
  if (-not (Test-Path $LogPath)) {
    return @{ Status = "NO_LOG"; Errors = 0; Fatals = 0; Warnings = 0 }
  }

  $text = Get-Content -Raw -Encoding UTF8 $LogPath

  $errors = 0
  $fatals = 0
  $warnings = 0

  if ($text -match "UVM_ERROR\s*:\s*(\d+)") {
    $errors = [int]$Matches[1]
  } else {
    $errors = ([regex]::Matches($text, "\bUVM_ERROR\b")).Count
  }

  if ($text -match "UVM_FATAL\s*:\s*(\d+)") {
    $fatals = [int]$Matches[1]
  } else {
    $fatals = ([regex]::Matches($text, "\bUVM_FATAL\b")).Count
  }

  if ($text -match "UVM_WARNING\s*:\s*(\d+)") {
    $warnings = [int]$Matches[1]
  } else {
    $warnings = ([regex]::Matches($text, "\bUVM_WARNING\b")).Count
  }

  $complete = ($text -match 'UVM_ERROR\s*:\s*0') -and
              ($text -match 'UVM_FATAL\s*:\s*0') -and ($text -match '\[SB_SUMMARY\]')
  $toolFailure = $text -match '(?m)^#?\s*\*\*\s*(Error|Fatal):'
  $status = if ($complete -and !$toolFailure -and ($errors -eq 0) -and
                ($fatals -eq 0) -and ($warnings -eq 0)) { "PASS" } else { "FAIL" }
  return @{ Status = $status; Errors = $errors; Fatals = $fatals; Warnings = $warnings }
}

Require-Tool "vlib"
Require-Tool "vlog"
Require-Tool "vsim"

New-Item -ItemType Directory -Force logs, reports | Out-Null

if (-not (Test-Path "work")) {
  vlib work | Out-Host
}

$compileOptions=@()
if ($NoWhitebox) { $compileOptions=@('+define+UART_NO_WHITEBOX') }
vlog -sv -assertdebug +acc +cover=bcesft @compileOptions -f $Filelist -l logs/compile_questa.log | Out-Host
if ($LASTEXITCODE -ne 0) {
  Write-EvidenceJson 'reports/regression_summary.json' @{ result='FAIL'; reason='Compilation failed'; source=$sourceIdentity }
  exit $LASTEXITCODE
}

$rows = @()
$index = 0

foreach ($test in $Tests) {
  $seedValue = $Seed + $index
  $logPath = "logs/${test}_${seedValue}.log"
  $ucdbPath = "reports/${test}_${seedValue}.ucdb"
  # These exact generated files belong to this test invocation. Never let a
  # previous successful UCDB satisfy a failed current run.
  foreach ($artifact in @($logPath, $ucdbPath)) {
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
  }
  $do = "coverage save -onexit $ucdbPath; run -all; quit -f"

  if ($DumpLoopbackVcd -and ($test -eq "uart_loopback_test")) {
    $vcdPath = "reports/${test}_${seedValue}.vcd"
    $vcdSignals = @(
      "/tb_apb_uart/presetn",
      "/tb_apb_uart/apb_vif/psel",
      "/tb_apb_uart/apb_vif/penable",
      "/tb_apb_uart/apb_vif/pwrite",
      "/tb_apb_uart/apb_vif/paddr",
      "/tb_apb_uart/apb_vif/pwdata",
      "/tb_apb_uart/apb_vif/prdata",
      "/tb_apb_uart/apb_vif/pslverr",
      "/tb_apb_uart/uart_vif/rx_i",
      "/tb_apb_uart/uart_vif/tx_o",
      "/tb_apb_uart/u_dut/tx_push",
      "/tb_apb_uart/u_dut/rx_pop",
      "/tb_apb_uart/u_dut/rx_empty"
    ) -join " "
    $do = "coverage save -onexit $ucdbPath; vcd file $vcdPath; vcd add $vcdSignals; run -all; quit -f"
  }

  $whitebox = if ($NoWhitebox) { 0 } else { 1 }
  vsim -c $Top "-gFIFO_ADDR_WIDTH=$FifoAddrWidth" "-gENABLE_WHITEBOX=$whitebox" "+UVM_TESTNAME=$test" "+PCLK_HALF_NS=$PclkHalfNs" "+UART_HALF_NS=$UartHalfNs" "+PCLK_PHASE_NS=$PclkPhaseNs" "+UART_PHASE_NS=$UartPhaseNs" -sv_seed $seedValue -coverage -assertdebug -do $do -l $logPath | Out-Host
  $runStatus = $LASTEXITCODE
  $parsed = Parse-UvmLog $logPath
  $outcome = Get-UvmOutcome (Get-Content -Raw $logPath) $runStatus
  if (!$outcome.pass) { $parsed.Status = 'FAIL' }

  if (($runStatus -ne 0) -or !(Test-Path $ucdbPath)) {
    $parsed.Status = "FAIL"
  }

  $rows += [pscustomobject]@{
    Test = $test
    Seed = $seedValue
    Status = $parsed.Status
    Errors = $parsed.Errors
    Fatals = $parsed.Fatals
    Warnings = $parsed.Warnings
    Log = $logPath
  }

  if ($runStatus -ne 0) {
    break
  }

  $index += 1
}

$passed = @($rows | Where-Object { $_.Status -eq "PASS" }).Count
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$summary = @(
  "# Regression Summary",
  "",
  "- Simulator: ``questa``",
  "- Time: ``$now``",
  "- FIFO address width: $FifoAddrWidth; white-box enabled: $(!$NoWhitebox)",
  "- Clock config: ``pclk_half=${PclkHalfNs}ns pclk_phase=${PclkPhaseNs}ns uart_half=${UartHalfNs}ns uart_phase=${UartPhaseNs}ns``",
  "",
  "| Test | Seed | Status | Errors | Fatals | Warnings | Log |",
  "| --- | ---: | --- | ---: | ---: | ---: | --- |"
)

foreach ($row in $rows) {
  $summary += "| $($row.Test) | $($row.Seed) | $($row.Status) | $($row.Errors) | $($row.Fatals) | $($row.Warnings) | ``$($row.Log)`` |"
}

$summary += ""
$summary += "Passed $passed/$($rows.Count) tests."
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/regression_summary.md"),
  $summary,
  $utf8NoBom
)

if ($passed -ne $rows.Count) {
  Write-EvidenceJson 'reports/regression_summary.json' @{ result='FAIL'; source=$sourceIdentity; tests=$rows }
  exit 1
}
Assert-SourceIdentity $sourceIdentity
Write-EvidenceJson 'reports/regression_summary.json' ([ordered]@{
  result='PASS'; source=$sourceIdentity; tests=$rows; fifoAddrWidth=$FifoAddrWidth; whiteboxEnabled=(!$NoWhitebox); clocks=@{
    pclkHalfNs=$PclkHalfNs; uartHalfNs=$UartHalfNs; pclkPhaseNs=$PclkPhaseNs; uartPhaseNs=$UartPhaseNs }
})
