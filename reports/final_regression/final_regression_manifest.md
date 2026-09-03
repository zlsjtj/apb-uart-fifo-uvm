# Final Regression Manifest

- Time: `2026-09-03 17:51:09`
- Baseline git commit: `67bc5f40ff1ea604b5d17dc009f411c6351d9606`
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
 M filelist.f
 M rtl/apb_uart.sv
 M scripts/merge_coverage.ps1
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_cdc_structural_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_p2_structural_check.ps1
 M scripts/run_questa.ps1
 M scripts/run_reg_model_check.ps1
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/uart_coverage.svh
 M tb/uvm/uart_env.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_pkg.sv
 M tb/uvm/uart_predictor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_scoreboard.svh
?? config/rtl_coverage_policy.psd1
?? config/verification_plan.psd1
?? rtl/apb_uart_cfg_cdc.sv
?? rtl/apb_uart_regs.sv
?? rtl/apb_uart_serial_core.sv
?? rtl/uart_baud_gen.sv
?? scripts/generate_rtl_coverage_gate.ps1
?? tb/uvm/uart_reset_monitor.svh
?? tb/uvm/uart_serial_cfg.svh
```

Full working-tree status is recorded separately because this run updates tracked evidence files.

```text
 M README.md
 M docs/coverage_closure.md
 M docs/final_regression_evidence.md
 M docs/p2_verification_architecture.md
 M docs/register_model.md
 M docs/traceability_matrix.md
 M docs/verification_architecture_closure.md
 M filelist.f
 M reports/acceptance_summary.md
 M reports/architecture_structural_summary.md
 M reports/baud_mutation_summary.md
 M reports/cdc_structural_summary.md
 M reports/control_mutation_summary.md
 M reports/fifo_mutation_summary.md
 M reports/final_regression/coverage/assertion_coverage.txt
 M reports/final_regression/coverage/code_coverage.txt
 M reports/final_regression/coverage/coverage_manifest.md
 M reports/final_regression/coverage/coverage_totals.txt
 M reports/final_regression/coverage/dut_bydu_coverage.txt
 M reports/final_regression/coverage/functional_coverage.txt
 M reports/final_regression/final_regression_manifest.md
 M reports/final_regression/final_regression_summary.md
 M reports/final_regression/seed_101_summary.md
 M reports/final_regression/seed_201_summary.md
 M reports/final_regression/seed_301_summary.md
 M reports/final_regression/source_manifest.md
 M reports/mutation_matrix.md
 M reports/mutation_summary.md
 M reports/p2_structural_summary.md
 M reports/register_model_structural_summary.md
 M reports/regression_summary.md
 M rtl/apb_uart.sv
 M scripts/merge_coverage.ps1
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_cdc_structural_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_p2_structural_check.ps1
 M scripts/run_questa.ps1
 M scripts/run_reg_model_check.ps1
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/uart_coverage.svh
 M tb/uvm/uart_env.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_pkg.sv
 M tb/uvm/uart_predictor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_scoreboard.svh
?? config/
?? docs/p0_p4_optimization_closure.md
?? reports/final_regression/coverage/rtl_coverage_gate.json
?? reports/final_regression/coverage/rtl_coverage_gate.md
?? rtl/apb_uart_cfg_cdc.sv
?? rtl/apb_uart_regs.sv
?? rtl/apb_uart_serial_core.sv
?? rtl/uart_baud_gen.sv
?? scripts/generate_rtl_coverage_gate.ps1
?? tb/uvm/uart_reset_monitor.svh
?? tb/uvm/uart_serial_cfg.svh
```
