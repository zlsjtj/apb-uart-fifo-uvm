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
$checks += Forbidden "tb/uvm/uart_driver.svh" 'bit_tick' "UART driver does not use DUT bit_tick"
$checks += Forbidden "tb/interfaces/uart_if.sv" 'bit_tick|cfg_apply|baud_uart_cfg|ctrl_uart_cfg' "Public UART interface contains no white-box probe signals"
$checks += Required "tb/interfaces/uart_probe_if.sv" 'interface\s+uart_probe_if' "White-box probe interface exists"
$checks += Required "tb/uvm/uart_monitor.svh" 'uart_serial_cfg' "TX monitor uses APB-observed runtime configuration"
$checks += Required "tb/uvm/uart_rx_monitor.svh" 'uart_serial_cfg' "RX monitor uses APB-observed runtime configuration"
$checks += Forbidden "tb/uvm/uart_monitor.svh" 'uart_probe_if|probe_vif|baud_uart_cfg|ctrl_uart_cfg' "TX monitor is a black-box serial observer"
$checks += Forbidden "tb/uvm/uart_rx_monitor.svh" 'uart_probe_if|probe_vif|baud_uart_cfg|ctrl_uart_cfg' "RX monitor is a black-box serial observer"
$checks += Required "tb/uvm/uart_env_cfg.svh" 'class\s+uart_env_cfg' "Shared environment configuration exists"
$checks += Forbidden "tb/uvm/uart_predictor.svh" 'RX_FIFO_DEPTH\s*=\s*16' "Predictor has no hard-coded FIFO depth"
$checks += Required "tb/uvm/uart_predictor.svh" 'cfg\.fifo_depth\(\)' "Predictor derives FIFO depth from configuration"
$checks += Required "tb/uvm/uart_virtual_sequencer.svh" 'class\s+uart_virtual_sequencer' "Virtual sequencer exists"
$checks += Required "tb/uvm/uart_virtual_sequences.svh" 'class\s+uart_external_rx_vseq' "Cross-interface virtual sequence exists"
$checks += Required "tb/uvm/uart_virtual_sequences.svh" 'class\s+uart_frame_error_vseq' "Frame-error flow uses a virtual sequence"
$checks += Required "tb/uvm/uart_virtual_sequences.svh" 'class\s+uart_rx_fifo_full_vseq' "RX FIFO flow uses a virtual sequence"
$checks += Required "tb/uvm/uart_virtual_sequences.svh" 'class\s+uart_reset_cdc_vseq' "Reset/CDC flow uses a virtual sequence"
$checks += Forbidden "tb/uvm/uart_env_cfg.svh" 'data_bits|stop_bits' "Environment config exposes no unsupported frame-format knobs"
$checks += Required "tb/uvm/uart_sequences.svh" 'sequences/uart_base_reg_sequences\.svh' "Sequence compatibility include uses feature fragments"
$checks += Required "tb/uvm/uart_tests.svh" 'tests/uart_base_reg_tests\.svh' "Test compatibility include uses feature fragments"
$checks += Required "scripts/run_acceptance.ps1" 'run_final_regression\.ps1' "One-command acceptance entry point exists"
$checks += Required "scripts/run_fifo_mutation_check.ps1" 'UART_MUTATE_FIFO_FULL_STUCK_LOW' "FIFO control mutation check exists"
$checks += Required "scripts/run_baud_mutation_check.ps1" 'UART_MUTATE_BAUD_TICK_FAST' "Baud-tick mutation check exists"
$checks += Required "tb/uvm/uart_reset_monitor.svh" 'class\s+uart_reset_monitor' "Unified reset monitor exists"
$checks += Required "tb/uvm/uart_env.svh" 'reset_mon\.ap\.connect\(reg_reset_sync\.reset_export\)' "Reset observer automatically resets the RAL mirror"
$checks += Required "tb/uvm/uart_env.svh" 'reset_mon\.ap\.connect\(pred\.reset_export\)' "Predictor consumes the shared reset event"
$checks += Required "tb/uvm/uart_env.svh" 'reset_mon\.ap\.connect\(sb\.reset_export\)' "Scoreboard consumes the shared reset event"
$checks += Required "tb/uvm/uart_env.svh" 'reset_mon\.ap\.connect\(cov\.reset_export\)' "Coverage consumes the shared reset event"
$checks += Required "rtl/apb_uart.sv" 'apb_uart_regs\s+u_regs' "Top level delegates APB registers"
$checks += Required "rtl/apb_uart.sv" 'apb_uart_cfg_cdc\s+u_cfg_cdc' "Top level delegates configuration CDC"
$checks += Required "rtl/apb_uart.sv" 'apb_uart_serial_core\s+u_serial_core' "Top level delegates UART serial logic"
$checks += Required "rtl/apb_uart_serial_core.sv" 'uart_baud_gen\s+u_baud_gen' "Serial core delegates baud generation"
$checks += Required "config/verification_plan.psd1" 'RegressionTests\s*=\s*@\(' "Declarative regression test list exists"
$checks += Required "config/verification_plan.psd1" 'StressProfiles\s*=\s*@\(' "Declarative stress profiles exist"
$checks += Forbidden "scripts/run_final_regression.ps1" '-ne\s+16|48/48' "Final regression contains no hard-coded run count"
$checks += Required "config/rtl_coverage_policy.psd1" 'Gates\s*=\s*@\(' "RTL-only coverage policy exists"
$checks += Required "scripts/generate_rtl_coverage_gate.ps1" 'rtl_coverage_gate\.json' "Machine-readable RTL coverage gate exists"
$checks += Required "tb/uvm/uart_monitor.svh" 'serial_cfg\.snapshot' "TX monitor freezes its frame configuration"
$checks += Required "tb/uvm/uart_rx_monitor.svh" 'serial_cfg\.snapshot' "RX monitor freezes its frame configuration"
$checks += Required "tb/uvm/tests/uart_base_reg_tests.svh" 'class\s+uart_config_stress_test' "Configuration busy/reset stress test exists"
$checks += Required "scripts/run_static_checks.ps1" 'rtl_lint\.log' "Reproducible RTL lint entry point exists"
$checks += Required "scripts/vivado_synth.tcl" 'report_timing_summary' "Reproducible synthesis and timing report flow exists"
$checks += Required "scripts/vivado_synth.tcl" 'report_cdc' "Vivado CDC report is generated"
$checks += Required "config/mutation_plan.psd1" 'Cases\s*=\s*@\(' "Declarative mutation plan exists"
$checks += Required "scripts/run_mutation_campaign.ps1" 'mutation_campaign\.json' "Machine-readable mutation result exists"

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
