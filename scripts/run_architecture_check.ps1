$ErrorActionPreference = "Stop"

function Required([string]$Path, [string]$Pattern, [string]$Name) {
  $ok = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{ Name = $Name; Result = if ($ok) { "PASS" } else { "FAIL" } }
}

function Forbidden([string]$Path, [string]$Pattern, [string]$Name) {
  $found = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{ Name = $Name; Result = if (-not $found) { "PASS" } else { "FAIL" } }
}

$checks = @()
$checks += Forbidden "tb/uvm/uart_monitor.svh" 'bit_tick' "TX monitor does not use DUT bit_tick"
$checks += Forbidden "tb/uvm/uart_rx_monitor.svh" 'bit_tick' "RX monitor does not use DUT bit_tick"
$checks += Required "tb/uvm/uart_monitor.svh" 'baud_uart_cfg' "TX monitor uses effective BAUD configuration"
$checks += Required "tb/uvm/uart_rx_monitor.svh" 'baud_uart_cfg' "RX monitor uses effective BAUD configuration"
$checks += Required "tb/uvm/uart_env_cfg.svh" 'class\s+uart_env_cfg' "Shared environment configuration exists"
$checks += Forbidden "tb/uvm/uart_predictor.svh" 'RX_FIFO_DEPTH\s*=\s*16' "Predictor has no hard-coded FIFO depth"
$checks += Required "tb/uvm/uart_predictor.svh" 'cfg\.fifo_depth\(\)' "Predictor derives FIFO depth from configuration"
$checks += Required "tb/uvm/uart_virtual_sequencer.svh" 'class\s+uart_virtual_sequencer' "Virtual sequencer exists"
$checks += Required "tb/uvm/uart_virtual_sequences.svh" 'class\s+uart_external_rx_vseq' "Cross-interface virtual sequence exists"
$checks += Required "tb/uvm/uart_sequences.svh" 'sequences/uart_base_reg_sequences\.svh' "Sequence compatibility include uses feature fragments"
$checks += Required "tb/uvm/uart_tests.svh" 'tests/uart_base_reg_tests\.svh' "Test compatibility include uses feature fragments"
$checks += Required "scripts/run_acceptance.ps1" 'run_final_regression\.ps1' "One-command acceptance entry point exists"
$checks += Required "scripts/run_fifo_mutation_check.ps1" 'UART_MUTATE_FIFO_FULL_STUCK_LOW' "FIFO control mutation check exists"

$failed = @($checks | Where-Object { $_.Result -ne "PASS" })
$reportPath = "reports/architecture_structural_summary.md"
New-Item -ItemType Directory -Force (Split-Path -Parent $reportPath) | Out-Null
$report = @(
  "# Architecture Structural Summary", "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Result: ``$(if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' })``",
  "- Checks: ``$($checks.Count - $failed.Count)/$($checks.Count)``", "",
  "| Check | Result |", "| --- | --- |"
)
foreach ($check in $checks) {
  Write-Host "$($check.Result): $($check.Name)"
  $report += "| $($check.Name) | $($check.Result) |"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $reportPath), $report, $utf8NoBom)

if ($failed.Count -ne 0) {
  throw "Architecture structural check failed: $($failed.Count)/$($checks.Count) checks failed."
}
Write-Host "Architecture structural check passed: $($checks.Count)/$($checks.Count)"

