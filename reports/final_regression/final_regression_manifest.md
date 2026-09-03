# Final Regression Manifest

- Time: `2026-09-03 17:01:17`
- Baseline git commit: `fb44c1edcbb9fdb572e76fe8867c166e5d590e5f`
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
 M rtl/apb_uart_reg_pkg.sv
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_mutation_suite.ps1
 M scripts/run_questa.ps1
 M tb/interfaces/uart_if.sv
 M tb/top/tb_apb_uart.sv
 M tb/uvm/sequences/uart_functional_sequences.svh
 M tb/uvm/sequences/uart_misc_sequences.svh
 M tb/uvm/sequences/uart_rx_fifo_sequences.svh
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/tests/uart_cdc_timing_tests.svh
 M tb/uvm/tests/uart_functional_tests.svh
 M tb/uvm/tests/uart_misc_tests.svh
 M tb/uvm/uart_config_monitor.svh
 M tb/uvm/uart_driver.svh
 M tb/uvm/uart_env_cfg.svh
 M tb/uvm/uart_item.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_virtual_sequences.svh
?? scripts/run_baud_mutation_check.ps1
?? tb/interfaces/uart_probe_if.sv
```

Full working-tree status is recorded separately because this run updates tracked evidence files.

```text
 M README.md
 M docs/architecture_optimization.md
 M docs/bug_closure_case.md
 M docs/cdc_analysis.md
 M docs/coverage_closure.md
 M docs/debug_notes.md
 M docs/final_regression_evidence.md
 M docs/p2_verification_architecture.md
 M docs/register_model.md
 M docs/requirements_and_scope.md
 M docs/traceability_matrix.md
 M filelist.f
 M reports/architecture_structural_summary.md
 M reports/cdc_structural_summary.md
 M reports/final_regression/coverage/assertion_coverage.txt
 M reports/final_regression/coverage/code_coverage.txt
 M reports/final_regression/coverage/coverage_manifest.md
 M reports/final_regression/coverage/coverage_totals.txt
 M reports/final_regression/coverage/dut_bydu_coverage.txt
 M reports/final_regression/coverage/functional_coverage.txt
 M reports/final_regression/final_regression_summary.md
 M reports/final_regression/seed_101_summary.md
 M reports/final_regression/seed_201_summary.md
 M reports/final_regression/seed_301_summary.md
 M reports/final_regression/source_manifest.md
 M reports/p2_structural_summary.md
 M reports/register_model_structural_summary.md
 M reports/regression_summary.md
 M rtl/apb_uart.sv
 M rtl/apb_uart_reg_pkg.sv
 M scripts/run_acceptance.ps1
 M scripts/run_architecture_check.ps1
 M scripts/run_final_regression.ps1
 M scripts/run_mutation_suite.ps1
 M scripts/run_questa.ps1
 M tb/interfaces/uart_if.sv
 M tb/top/tb_apb_uart.sv
 M tb/uvm/sequences/uart_functional_sequences.svh
 M tb/uvm/sequences/uart_misc_sequences.svh
 M tb/uvm/sequences/uart_rx_fifo_sequences.svh
 M tb/uvm/tests/uart_base_reg_tests.svh
 M tb/uvm/tests/uart_cdc_timing_tests.svh
 M tb/uvm/tests/uart_functional_tests.svh
 M tb/uvm/tests/uart_misc_tests.svh
 M tb/uvm/uart_config_monitor.svh
 M tb/uvm/uart_driver.svh
 M tb/uvm/uart_env_cfg.svh
 M tb/uvm/uart_item.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_rx_monitor.svh
 M tb/uvm/uart_virtual_sequences.svh
?? docs/verification_architecture_closure.md
?? reports/baud_mutation_summary.md
?? scripts/run_baud_mutation_check.ps1
?? tb/interfaces/uart_probe_if.sv
```
