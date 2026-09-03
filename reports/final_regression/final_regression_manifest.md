# Final Regression Manifest

- Time: `2026-09-03 15:18:35`
- Baseline git commit: `4f48b7fd94c0c136ba12a5e7c031c67c343a43db`
- Working tree clean: `False`
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

The working tree was not clean. The commit is a baseline only; use source_manifest.md to identify the exact simulated files.

```text
 M README.md
 M docs/bug_closure_case.md
 M docs/cdc_analysis.md
 M docs/coverage_closure.md
 M docs/coverage_summary.md
 M docs/debug_notes.md
 M docs/final_regression_evidence.md
 M docs/requirements_and_scope.md
 M docs/traceability_matrix.md
 M filelist.f
 M reports/cdc_structural_summary.md
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
 M reports/mutation_summary.md
 M reports/regression_summary.md
 M rtl/apb_uart.sv
 M rtl/apb_uart_sva.sv
 M rtl/async_fifo.sv
 M scripts/run_final_regression.ps1
 M scripts/run_questa.ps1
 M tb/interfaces/uart_if.sv
 M tb/top/tb_apb_uart.sv
 M tb/uvm/uart_agent.svh
 M tb/uvm/uart_coverage.svh
 M tb/uvm/uart_driver.svh
 M tb/uvm/uart_env.svh
 M tb/uvm/uart_item.svh
 M tb/uvm/uart_monitor.svh
 M tb/uvm/uart_pkg.sv
 M tb/uvm/uart_scoreboard.svh
 M tb/uvm/uart_sequences.svh
 M tb/uvm/uart_tests.svh
?? docs/architecture_optimization.md
?? docs/p2_verification_architecture.md
?? docs/register_model.md
?? reports/architecture_structural_summary.md
?? reports/config_latency_summary.md
?? reports/control_mutation_summary.md
?? reports/fifo_mutation_summary.md
?? reports/mutation_matrix.md
?? reports/p2_structural_summary.md
?? reports/register_model_structural_summary.md
?? rtl/apb_uart_reg_pkg.sv
?? scripts/run_acceptance.ps1
?? scripts/run_architecture_check.ps1
?? scripts/run_control_mutation_check.ps1
?? scripts/run_fifo_mutation_check.ps1
?? scripts/run_mutation_suite.ps1
?? scripts/run_p2_structural_check.ps1
?? scripts/run_reg_model_check.ps1
?? tb/uvm/sequences/
?? tb/uvm/tests/
?? tb/uvm/uart_config_monitor.svh
?? tb/uvm/uart_env_cfg.svh
?? tb/uvm/uart_predictor.svh
?? tb/uvm/uart_reg_model.svh
?? tb/uvm/uart_rx_monitor.svh
?? tb/uvm/uart_virtual_sequencer.svh
?? tb/uvm/uart_virtual_sequences.svh
```
