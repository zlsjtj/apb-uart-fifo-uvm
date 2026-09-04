# Final Regression Manifest

- Time: `2026-09-04 23:51:58`
- Baseline git commit: `66f37583b32158c0064e0aabb8a34be639cd1dac`
- Source tree clean relative to baseline: `False`
- Full working tree clean: `False`
- Simulator: `Model Technology ModelSim SE-64 vlog 10.4 Compiler 2014.12 Dec  3 2014`
- UVM: `UVM-1.1d built-in; Questa UVM-1.2.2 reported by simulation log`
- Command: `& .\scripts\run_final_regression.ps1 -Seeds @(101, 201, 301)`
- Regression summary: `reports\final_regression\final_regression_summary.md`
- Coverage directory: `reports\final_regression\coverage`
- Register-model structural report: `reports/register_model_structural_summary.md`
- CDC structural report: `reports/cdc_structural_summary.md`
- P2 structural report: `reports/p2_structural_summary.md`
- Architecture structural report: `reports/architecture_structural_summary.md`
- Source hashes: `reports\final_regression\source_manifest.md`

## Working tree status

The source tree differs from the baseline commit. Use source_manifest.md to identify the exact simulated files. Generated reports are not used to decide source cleanliness.

```text
 M config/verification_plan.psd1
 M rtl/apb_uart.sv
 M rtl/apb_uart_cfg_cdc.sv
 M rtl/apb_uart_sva.sv
 M rtl/async_fifo.sv
 M rtl/reset_sync.sv
 M rtl/uart_rx.sv
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_cdc_structural_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_mutation_suite.ps1
 M scripts/run_p2_structural_check.ps1
 M tb/interfaces/uart_probe_if.sv
 M tb/top/tb_apb_uart.sv
 M tb/uvm/sequences/uart_base_reg_sequences.svh
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_serial_cfg.svh
?? config/mutation_plan.psd1
?? rtl_filelist.f
?? scripts/run_mutation_campaign.ps1
?? scripts/run_static_checks.ps1
?? scripts/run_vivado_synth.ps1
?? scripts/vivado_synth.tcl
```

Full working-tree status is recorded separately because this run updates tracked evidence files.

```text
 M README.md
 M config/verification_plan.psd1
 M reports/architecture_structural_summary.md
 M reports/cdc_structural_summary.md
 M reports/final_regression/coverage/assertion_coverage.txt
 M reports/final_regression/coverage/code_coverage.txt
 M reports/final_regression/coverage/coverage_manifest.md
 M reports/final_regression/coverage/coverage_totals.txt
 M reports/final_regression/coverage/dut_bydu_coverage.txt
 M reports/final_regression/coverage/functional_coverage.txt
 M reports/final_regression/coverage/rtl_coverage_gate.json
 M reports/final_regression/coverage/rtl_coverage_gate.md
 M reports/final_regression/final_regression_summary.md
 M reports/final_regression/seed_101_summary.md
 M reports/final_regression/seed_201_summary.md
 M reports/final_regression/seed_301_summary.md
 M reports/final_regression/source_manifest.md
 M reports/p2_structural_summary.md
 M reports/register_model_structural_summary.md
 M reports/regression_summary.md
 M rtl/apb_uart.sv
 M rtl/apb_uart_cfg_cdc.sv
 M rtl/apb_uart_sva.sv
 M rtl/async_fifo.sv
 M rtl/reset_sync.sv
 M rtl/uart_rx.sv
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_cdc_structural_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_mutation_suite.ps1
 M scripts/run_p2_structural_check.ps1
 M tb/interfaces/uart_probe_if.sv
 M tb/top/tb_apb_uart.sv
 M tb/uvm/sequences/uart_base_reg_sequences.svh
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_serial_cfg.svh
?? .Xil/
?? config/mutation_plan.psd1
?? docs/current_architecture_and_optimization.md
?? reports/cdc_structural_summary.json
?? reports/mutation_campaign.json
?? reports/mutation_campaign.md
?? reports/precommit_regression/
?? reports/static_checks.json
?? reports/static_checks.md
?? reports/synthesis/
?? rtl_filelist.f
?? scripts/run_mutation_campaign.ps1
?? scripts/run_static_checks.ps1
?? scripts/run_vivado_synth.ps1
?? scripts/vivado_synth.tcl
```
