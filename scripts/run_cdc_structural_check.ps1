$ErrorActionPreference = "Stop"

function Test-RequiredPattern([string]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if ($matched) { "PASS" } else { "FAIL" }
    Detail = if ($matched) { "required structure found" } else { "required structure not found" }
  }
}

function Test-ForbiddenPattern([string]$Path, [string]$Pattern, [string]$Name) {
  $matched = Select-String -Path $Path -Pattern $Pattern -Quiet
  return [pscustomobject]@{
    Name = $Name
    Result = if (-not $matched) { "PASS" } else { "FAIL" }
    Detail = if (-not $matched) { "legacy structure absent" } else { "legacy structure still present" }
  }
}

New-Item -ItemType Directory -Force reports | Out-Null

$checks = @()
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_ctrl_hold' -Name "Configuration mailbox holds a stable CTRL payload"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_baud_hold' -Name "Configuration mailbox holds a stable BAUD payload"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_req_tgl' -Name "Configuration request uses a toggle"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_ack_tgl' -Name "Configuration acknowledgement uses a toggle"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*cfg_ack_pclk_q1' -Name "UART-to-APB acknowledgement synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*cfg_req_uart_q1' -Name "APB-to-UART request synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/reset_sync.sv" -Pattern 'ASYNC_REG = "TRUE".*sync_pipe' -Name "Reset-release synchronizer stages are marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'fifo_async_rst_n\s*=\s*presetn\s*&&\s*uart_rst_n' -Name "Shared FIFO reset asserts on either external reset"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_pclk_reset_sync' -Name "APB domain uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_uart_reset_sync' -Name "UART domain uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_fifo_pclk_reset_sync' -Name "FIFO APB side uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'u_fifo_uart_reset_sync' -Name "FIFO UART side uses a reset-release synchronizer"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'cfg_uart_rst_n\s*=\s*fifo_uart_rst_n' -Name "UART mailbox uses the synchronized shared reset"
$checks += Test-ForbiddenPattern -Path "rtl/apb_uart.sv" -Pattern '\.wr_rst_n\s*\(presetn\)|\.rd_rst_n\s*\(presetn\)|\.wr_rst_n\s*\(uart_rst_n\)|\.rd_rst_n\s*\(uart_rst_n\)' -Name "FIFO ports do not deassert directly from external resets"
$checks += Test-ForbiddenPattern -Path "rtl/apb_uart.sv" -Pattern 'ctrl_uart_q[12]|baud_uart_q[12]' -Name "Legacy per-bit CTRL/BAUD synchronizers removed"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*rx_full_pclk_q1' -Name "RX full status synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'ASYNC_REG = "TRUE".*rx_frame_err_pclk_q1' -Name "Frame error status synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/apb_uart.sv" -Pattern 'rx_frame_err_pclk_q2, irq_o, rx_full_pclk_q2' -Name "STATUS uses synchronized UART-domain flags"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'ASYNC_REG = "TRUE".*rgray_wclk_q1' -Name "FIFO read-pointer synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'ASYNC_REG = "TRUE".*wgray_rclk_q1' -Name "FIFO write-pointer synchronizer is marked"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'bin2gray' -Name "FIFO Gray-code conversion is present"
$checks += Test-RequiredPattern -Path "rtl/async_fifo.sv" -Pattern 'rgray_wclk_q2|wgray_rclk_q2' -Name "FIFO uses second-stage synchronized pointers"

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

if ($passed -ne $checks.Count) {
  throw "CDC structural check failed. See reports/cdc_structural_summary.md"
}

Write-Host "CDC structural check passed: $passed/$($checks.Count)"
