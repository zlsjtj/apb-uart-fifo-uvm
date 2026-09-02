# Final Regression Manifest

- Time: `2026-09-03 00:13:59`
- Baseline git commit: `4d272d50a0bff5d0937519b699da3bd56a6c6a87`
- Working tree clean: `False`
- Simulator: `Model Technology ModelSim SE-64 vlog 10.4 Compiler 2014.12 Dec  3 2014`
- UVM: `UVM-1.1d built-in; Questa UVM-1.2.2 reported by simulation log`
- Command: `& .\scripts\run_final_regression.ps1 -Seeds @(101, 201, 301)`
- Regression summary: `reports\final_regression\final_regression_summary.md`
- Coverage directory: `reports\final_regression\coverage`
- CDC structural report: `reports/cdc_structural_summary.md`
- Source hashes: `reports\final_regression\source_manifest.md`

## Working tree status

The working tree was not clean. The commit is a baseline only; use source_manifest.md to identify the exact simulated files.

```text
 M .gitignore
 M README.md
 M docs/coverage_summary.md
 M docs/debug_notes.md
 M filelist.f
 M reports/regression_summary.md
 M rtl/apb_uart.sv
 M rtl/apb_uart_sva.sv
 M rtl/async_fifo.sv
 M rtl/uart_rx.sv
 M scripts/run_questa.ps1
 M tb/top/tb_apb_uart.sv
 M tb/uvm/apb_driver.svh
 M tb/uvm/uart_coverage.svh
 M tb/uvm/uart_driver.svh
 M tb/uvm/uart_scoreboard.svh
 M tb/uvm/uart_sequences.svh
 M tb/uvm/uart_tests.svh
?? docs/bug_closure_case.md
?? docs/cdc_analysis.md
?? docs/coverage_closure.md
?? docs/final_regression_evidence.md
?? docs/requirements_and_scope.md
?? docs/traceability_matrix.md
?? reports/baud_timing_summary.md
?? reports/cdc_structural_summary.md
?? reports/coverage/
?? reports/final_regression/
?? reports/mutation_summary.md
?? reports/reset_cdc_summary.md
?? rtl/reset_sync.sv
?? scripts/merge_coverage.ps1
?? scripts/run_cdc_structural_check.ps1
?? scripts/run_final_regression.ps1
?? scripts/run_mutation_check.ps1
?? tb/interfaces/reset_if.sv
```
