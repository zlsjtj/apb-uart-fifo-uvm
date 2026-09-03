$ErrorActionPreference = "Stop"

function Test-RequiredPattern([string]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if ($matched) { "PASS" } else { "FAIL" }
  }
}

function Test-ForbiddenPattern([string[]]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if (-not $matched) { "PASS" } else { "FAIL" }
  }
}

$checks = @()
$checks += Test-RequiredPattern "rtl/apb_uart_reg_pkg.sv" 'UART_ADDR_CTRL\s*=\s*8.h00' "CTRL address has one canonical definition"
$checks += Test-RequiredPattern "rtl/apb_uart_reg_pkg.sv" 'UART_ADDR_STATUS\s*=\s*8.h04' "STATUS address has one canonical definition"
$checks += Test-RequiredPattern "rtl/apb_uart_reg_pkg.sv" 'UART_ADDR_BAUD\s*=\s*8.h08' "BAUD address has one canonical definition"
$checks += Test-RequiredPattern "rtl/apb_uart_reg_pkg.sv" 'UART_ADDR_TXDATA\s*=\s*8.h0c' "TXDATA address has one canonical definition"
$checks += Test-RequiredPattern "rtl/apb_uart_reg_pkg.sv" 'UART_ADDR_RXDATA\s*=\s*8.h10' "RXDATA address has one canonical definition"
$checks += Test-ForbiddenPattern -Path @("rtl/apb_uart.sv", "rtl/apb_uart_regs.sv", "rtl/apb_uart_sva.sv", "tb/uvm/sequences/*.svh") -Pattern 'ADDR_\w+\s*=\s*8.h' -Name "RTL, SVA and sequences contain no numeric address copies"
$checks += Test-RequiredPattern "tb/uvm/uart_reg_model.svh" 'class\s+uart_reg_block\s+extends\s+uvm_reg_block' "RAL register block exists"
$checks += Test-RequiredPattern "tb/uvm/uart_reg_model.svh" 'add_reg\(ctrl,\s+UART_ADDR_CTRL,\s+"RW"\)' "RAL map uses canonical CTRL definition"
$checks += Test-RequiredPattern "tb/uvm/uart_reg_model.svh" 'add_reg\(status,\s+UART_ADDR_STATUS,\s+"RO"\)' "RAL map models STATUS as read-only"
$checks += Test-RequiredPattern "tb/uvm/uart_reg_model.svh" 'add_reg\(txdata,\s+UART_ADDR_TXDATA,\s+"WO"\)' "RAL map models TXDATA as write-only"
$checks += Test-RequiredPattern "tb/uvm/uart_reg_model.svh" 'class\s+uart_apb_reg_adapter\s+extends\s+uvm_reg_adapter' "APB register adapter exists"
$checks += Test-RequiredPattern "tb/uvm/uart_env.svh" 'uvm_reg_predictor\s*#\(apb_item\)' "Typed APB predictor is instantiated"
$checks += Test-RequiredPattern "tb/uvm/uart_env.svh" 'apb.mon.ap.connect\(reg_predictor.bus_in\)' "APB monitor feeds the predictor"
$checks += Test-RequiredPattern "tb/uvm/tests/uart_base_reg_tests.svh" 'class\s+uart_ral_test' "RAL access and reset test exists"
$checks += Test-RequiredPattern "tb/uvm/uart_reset_monitor.svh" 'regmodel\.reset\(\)' "RAL mirror reset is driven by the unified reset observer"
$checks += Test-ForbiddenPattern -Path @("tb/uvm/tests/*.svh") -Pattern 'env\.regmodel\.reset\(\)' -Name "Tests do not manually repair the RAL mirror"

$failed = @($checks | Where-Object { $_.Result -ne "PASS" })
foreach ($check in $checks) {
  Write-Host "$($check.Result): $($check.Name)"
}

$reportPath = "reports/register_model_structural_summary.md"
$reportDir = Split-Path -Parent $reportPath
New-Item -ItemType Directory -Force $reportDir | Out-Null
$report = @(
  "# Register Model Structural Summary",
  "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Result: ``$(if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' })``",
  "- Checks: ``$($checks.Count - $failed.Count)/$($checks.Count)``",
  "",
  "| Check | Result |",
  "| --- | --- |"
)
foreach ($check in $checks) {
  $report += "| $($check.Name) | $($check.Result) |"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $reportPath), $report, $utf8NoBom)

if ($failed.Count -ne 0) {
  throw "Register-model structural check failed: $($failed.Count)/$($checks.Count) checks failed."
}

Write-Host "Register-model structural check passed: $($checks.Count)/$($checks.Count)"
Write-Host "Register-model structural report: $reportPath"
