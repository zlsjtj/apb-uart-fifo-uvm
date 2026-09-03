$ErrorActionPreference = "Stop"

function Test-RequiredPattern([string]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{ Name = $Name; Result = if ($matched) { "PASS" } else { "FAIL" } }
}

function Test-ForbiddenPattern([string]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{ Name = $Name; Result = if (-not $matched) { "PASS" } else { "FAIL" } }
}

$checks = @()
$checks += Test-RequiredPattern "tb/uvm/uart_rx_monitor.svh" 'class\s+uart_rx_monitor' "Independent RX-pin monitor exists"
$checks += Test-RequiredPattern "tb/uvm/uart_rx_monitor.svh" 'tr\.data\[i\]\s*=\s*vif\.mon_cb\.rx_i' "RX monitor decodes observed pin samples"
$checks += Test-RequiredPattern "tb/uvm/uart_monitor.svh" 'uart_serial_cfg' "TX monitor uses the APB-observed serial model"
$checks += Test-RequiredPattern "tb/uvm/uart_rx_monitor.svh" 'uart_serial_cfg' "RX monitor uses the APB-observed serial model"
$checks += Test-ForbiddenPattern "tb/uvm/uart_monitor.svh" 'uart_probe_if|probe_vif|baud_uart_cfg|ctrl_uart_cfg' "TX monitor is independent of white-box probes"
$checks += Test-ForbiddenPattern "tb/uvm/uart_rx_monitor.svh" 'uart_probe_if|probe_vif|baud_uart_cfg|ctrl_uart_cfg' "RX monitor is independent of white-box probes"
$checks += Test-RequiredPattern "tb/uvm/uart_agent.svh" 'uart_rx_monitor::type_id::create' "UART agent builds the RX monitor"
$checks += Test-ForbiddenPattern "tb/uvm/uart_env.svh" 'uart\.drv\.ap\.connect\(sb' "Scoreboard does not trust driver transactions"
$checks += Test-ForbiddenPattern "tb/uvm/uart_driver.svh" 'uvm_analysis_port' "UART driver publishes no expected-result stream"
$checks += Test-RequiredPattern "tb/uvm/uart_predictor.svh" 'class\s+uart_predictor' "Reference predictor is separate from scoreboard"
$checks += Test-RequiredPattern "tb/uvm/uart_env.svh" 'pred\.exp_tx_ap\.connect\(sb\.exp_tx_export\)' "Expected TX stream connects predictor to scoreboard"
$checks += Test-RequiredPattern "tb/uvm/uart_env.svh" 'pred\.exp_rx_ap\.connect\(sb\.exp_rx_export\)' "Expected RX stream connects predictor to scoreboard"
$checks += Test-RequiredPattern "rtl/apb_uart_cfg_cdc.sv" 'cfg_apply_uart' "UART-domain configuration apply event exists"
$checks += Test-RequiredPattern "tb/uvm/tests/uart_base_reg_tests.svh" 'class\s+uart_config_latency_test' "APB-write versus UART-apply timing test exists"
$checks += Test-RequiredPattern "scripts/run_control_mutation_check.ps1" 'UART_MUTATE_IRQ_STUCK_LOW' "IRQ control mutation check exists"

$failed = @($checks | Where-Object { $_.Result -ne "PASS" })
$reportPath = "reports/p2_structural_summary.md"
New-Item -ItemType Directory -Force (Split-Path -Parent $reportPath) | Out-Null
$report = @(
  "# P2 Structural Summary", "",
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
  throw "P2 structural check failed: $($failed.Count)/$($checks.Count) checks failed."
}
Write-Host "P2 structural check passed: $($checks.Count)/$($checks.Count)"
Write-Host "P2 structural report: $reportPath"
