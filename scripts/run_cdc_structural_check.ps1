$ErrorActionPreference = "Stop"

function Test-RequiredPattern([string[]]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if ($matched) { "PASS" } else { "FAIL" }
    Detail = if ($matched) { "required structure found" } else { "required structure not found" }
  }
}

function Test-ForbiddenPattern([string[]]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if (-not $matched) { "PASS" } else { "FAIL" }
    Detail = if (-not $matched) { "legacy structure absent" } else { "legacy structure still present" }
  }
}

New-Item -ItemType Directory -Force reports | Out-Null

$checks = @()
$checks += Test-RequiredPattern -Path 'rtl/apb_uart.sv' -Pattern '\.pclk_rst_n\(fifo_pclk_rst_n\)' -Name 'Both mailbox domains reset with the shared FIFO epoch'
$checks += Test-RequiredPattern -Path 'rtl/apb_uart.sv' -Pattern '\.tx_empty\(tx_empty_pclk_q2\)' -Name 'APB sees the returned synchronized TX empty flag'
$checks += Test-ForbiddenPattern -Path 'rtl/apb_uart_cfg_cdc.sv' -Pattern 'if\s*\(!cfg_uart_initialized\)' -Name 'Startup cannot bypass the synchronized request'
$checks += Test-RequiredPattern -Path 'rtl/async_fifo.sv' -Pattern 'wr_full_q\s*<=' -Name 'FIFO full flag is registered in its source domain'
$checks += Test-RequiredPattern -Path 'rtl/async_fifo.sv' -Pattern 'rd_empty\s*<=' -Name 'FIFO empty flag is registered in its source domain'
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'cfg_ctrl_hold' -Name "Configuration mailbox holds a stable CTRL payload"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'cfg_baud_hold' -Name "Configuration mailbox holds a stable BAUD payload"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'cfg_req_tgl' -Name "Configuration request uses a toggle"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'cfg_ack_tgl' -Name "Configuration acknowledgement uses a toggle"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'ASYNC_REG = "TRUE".*cfg_ack_meta' -Name "UART-to-APB acknowledgement synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_cfg_cdc.sv" -Pattern 'ASYNC_REG = "TRUE".*cfg_req_meta' -Name "APB-to-UART request synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/reset_sync.sv" -Pattern 'ASYNC_REG = "TRUE".*sync_pipe' -Name "Reset-release synchronizer stages are marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'fifo_async_rst_n\s*=\s*presetn\s*&&\s*uart_rst_n' -Name "Shared FIFO reset asserts on either external reset"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_pclk_reset_sync' -Name "APB domain uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_uart_reset_sync' -Name "UART domain uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_fifo_pclk_reset_sync' -Name "FIFO APB side uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_fifo_uart_reset_sync' -Name "FIFO UART side uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_uart_rst_n\s*=\s*fifo_uart_rst_n' -Name "UART mailbox uses the synchronized shared reset"
$checks += Test-ForbiddenPattern -Path "rtl/apb_uart.sv" -Pattern '\.wr_rst_n\s*\(presetn\)|\.rd_rst_n\s*\(presetn\)|\.wr_rst_n\s*\(uart_rst_n\)|\.rd_rst_n\s*\(uart_rst_n\)' -Name "FIFO ports do not deassert directly from external resets"
$checks += Test-ForbiddenPattern -Path @("rtl/apb_uart.sv", "rtl/apb_uart_cfg_cdc.sv") -Pattern 'ctrl_uart_q[12]|baud_uart_q[12]' -Name "Legacy per-bit CTRL/BAUD synchronizers removed"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*rx_full_pclk_q1' -Name "RX full status synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*rx_frame_err_pclk_q1' -Name "Frame error status synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_regs.sv" -Pattern 'rx_frame_err, irq, rx_full, rx_empty' -Name "STATUS uses synchronized UART-domain flags supplied by the top level"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'ASYNC_REG = "TRUE".*rgray_wclk_q1' -Name "FIFO read-pointer synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'ASYNC_REG = "TRUE".*wgray_rclk_q1' -Name "FIFO write-pointer synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'bin2gray' -Name "FIFO Gray-code conversion is present"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'rgray_wclk_q2|wgray_rclk_q2' -Name "FIFO uses second-stage synchronized pointers"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'config_payload_stable_while_busy' -Name "Mailbox payload stability is asserted"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'config_request_eventually_ack' -Name "Request-to-acknowledgement progress is asserted"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'config_apply_is_single_cycle' -Name "Configuration apply is asserted to be one cycle"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'config_ack_changes_with_apply' -Name "Acknowledgement changes are tied to apply"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'pclk_reset_release_has_sync_latency' -Name "APB reset-release latency is asserted"
$checks += Test-RequiredPattern -Path "rtl/apb_uart_sva.sv" -Pattern 'uart_reset_release_has_sync_latency' -Name "UART reset-release latency is asserted"
$checks += Test-RequiredPattern -Path "tb/uvm/tests/uart_base_reg_tests.svh" -Pattern 'class\s+uart_config_stress_test' -Name "Mailbox busy and independent-reset stress test exists"
$checks += Test-RequiredPattern -Path "tb/uvm/tests/uart_base_reg_tests.svh" -Pattern 'pulse_uart_reset' -Name "UART-only reset recovery is exercised"

$availableCdcTool = @("questa_cdc", "qverify", "spyglass") |
  Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
  Select-Object -First 1
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$passed = @($checks | Where-Object { $_.Result -eq "PASS" }).Count
$report = @(
  "# CDC Structural Check Summary",
  "",
  "- Time: ``$now``",
  "- Commercial CDC tool available: ``$($null -ne $availableCdcTool)``",
  "- Scope: RTL structural rules only; this is not a replacement for signoff CDC analysis.",
  "- Result: $passed/$($checks.Count) checks passed.",
  "",
  "| Check | Result | Detail |",
  "| --- | --- | --- |"
)
foreach ($check in $checks) {
  $report += "| $($check.Name) | $($check.Result) | $($check.Detail) |"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/cdc_structural_summary.md"),
  $report,
  $utf8NoBom
)

$json = [ordered]@{
  generatedAt = $now
  result = if ($passed -eq $checks.Count) { "PASS" } else { "FAIL" }
  passed = $passed
  total = $checks.Count
  commercialCdcSignoffPerformed = $false
  checks = $checks
}
$json | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 reports/cdc_structural_summary.json

if ($passed -ne $checks.Count) {
  throw "CDC structural check failed. See reports/cdc_structural_summary.md"
}

Write-Host "CDC structural check passed: $passed/$($checks.Count)"
