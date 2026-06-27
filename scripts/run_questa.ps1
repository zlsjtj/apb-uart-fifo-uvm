param(
  [string[]]$Tests = @(
    "uart_reg_test",
    "uart_loopback_test",
    "uart_baud_loopback_test",
    "uart_external_rx_test",
    "uart_fifo_full_test",
    "uart_bad_access_test",
    "uart_random_test",
    "uart_recover_test"
  ),
  [int]$Seed = 1,
  [string]$Top = "tb_apb_uart",
  [string]$Filelist = "filelist.f",
  [switch]$DumpLoopbackVcd
)

$ErrorActionPreference = "Stop"

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

  $status = if (($errors -eq 0) -and ($fatals -eq 0)) { "PASS" } else { "FAIL" }
  return @{ Status = $status; Errors = $errors; Fatals = $fatals; Warnings = $warnings }
}

Require-Tool "vlib"
Require-Tool "vlog"
Require-Tool "vsim"

New-Item -ItemType Directory -Force logs, reports | Out-Null

if (-not (Test-Path "work")) {
  vlib work | Out-Host
}

vlog -sv -assertdebug +acc +cover=bcesft -f $Filelist -l logs/compile_questa.log | Out-Host
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$rows = @()
$index = 0

foreach ($test in $Tests) {
  $seedValue = $Seed + $index
  $logPath = "logs/${test}_${seedValue}.log"
  $ucdbPath = "reports/${test}_${seedValue}.ucdb"
  $do = "run -all; coverage save $ucdbPath; quit -f"

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
    $do = "vcd file $vcdPath; vcd add $vcdSignals; run -all; coverage save $ucdbPath; quit -f"
  }

  vsim -c $Top "+UVM_TESTNAME=$test" -sv_seed $seedValue -coverage -assertdebug -do $do -l $logPath | Out-Host
  $runStatus = $LASTEXITCODE
  $parsed = Parse-UvmLog $logPath

  if (($runStatus -ne 0) -and ($parsed.Status -eq "PASS")) {
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
  exit 1
}
