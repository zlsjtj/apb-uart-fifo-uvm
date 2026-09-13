# Final Regression Manifest

- Time: `2026-09-13 12:07:14`
- Baseline git commit: `5214f530f1a4d0caa5a6b1d682403e642dfbede3`
- Exact executed source identity: `3ab242e7d2064eced3654ecc9eaa54a89a547f3d9066f062285421da44e06488`
- Source remained unchanged during this run: `true`
- Simulator: `Model Technology ModelSim SE-64 vlog 10.4 Compiler 2014.12 Dec  3 2014`
- UVM: `UVM-1.1d built-in; Questa UVM-1.2.2 reported by simulation log`
- Command: `& .\scripts\run_final_regression.ps1 -Seeds @(2701, 2801, 2901)`
- Regression summary: `reports\final_regression\final_regression_summary.md`
- Coverage directory: `reports\final_regression\coverage`
- Register-model structural report: `reports/register_model_structural_summary.md`
- CDC structural report: `reports/cdc_structural_summary.md`
- P2 structural report: `reports/p2_structural_summary.md`
- Architecture structural report: `reports/architecture_structural_summary.md`
- Source hashes: `reports\final_regression\source_manifest.md`

## Working tree status

Git reports no tracked changes at this execution path. An isolated ignored snapshot is not proven to match HEAD by this result; source_manifest.json is the authoritative executed-source identity.

Full working-tree status is recorded separately because this run updates tracked evidence files.

```text
 M ../../../../.gitignore
 M ../../../../README.md
 M ../../../../config/mutation_plan.psd1
 M ../../../../config/rtl_coverage_policy.psd1
 M ../../../../config/verification_plan.psd1
 M ../../../../docs/architecture_optimization.md
 M ../../../../docs/bug_closure_case.md
 M ../../../../docs/cdc_analysis.md
 M ../../../../docs/coverage_closure.md
 M ../../../../docs/current_architecture_and_optimization.md
 M ../../../../docs/debug_notes.md
 M ../../../../docs/final_regression_evidence.md
 M ../../../../docs/p0_p4_optimization_closure.md
 M ../../../../docs/p2_verification_architecture.md
 M ../../../../docs/register_model.md
 M ../../../../docs/requirements_and_scope.md
 M ../../../../docs/traceability_matrix.md
 M ../../../../docs/verification_architecture_closure.md
 M ../../../../filelist.f
 M ../../../acceptance_summary.json
 M ../../../acceptance_summary.md
 M ../../../architecture_structural_summary.md
 M ../../../baud_mutation_summary.md
 M ../../../cdc_structural_summary.json
 M ../../../cdc_structural_summary.md
 M ../../../final_regression/coverage/assertion_coverage.txt
 M ../../../final_regression/coverage/code_coverage.txt
 M ../../../final_regression/coverage/coverage_manifest.md
 M ../../../final_regression/coverage/coverage_totals.txt
 M ../../../final_regression/coverage/dut_bydu_coverage.txt
 M ../../../final_regression/coverage/functional_coverage.txt
 M ../../../final_regression/coverage/rtl_coverage_gate.json
 M ../../../final_regression/coverage/rtl_coverage_gate.md
 M ../../../final_regression/final_regression_manifest.md
 M ../../../final_regression/final_regression_summary.md
 M ../../../final_regression/source_manifest.md
 M ../../../mutation_campaign.json
 M ../../../mutation_campaign.md
 M ../../../p2_structural_summary.md
 M ../../../register_model_structural_summary.md
 M ../../../regression_summary.md
 M ../../../static_checks.json
 M ../../../static_checks.md
 M ../../../synthesis/cdc.rpt
 M ../../../synthesis/qor.json
 M ../../../synthesis/summary.md
 M ../../../synthesis/timing_summary.rpt
 M ../../../synthesis/utilization.rpt
 M ../../../../rtl/apb_uart.sv
 M ../../../../rtl/apb_uart_cfg_cdc.sv
 M ../../../../rtl/apb_uart_reg_pkg.sv
 M ../../../../rtl/apb_uart_regs.sv
 M ../../../../rtl/apb_uart_serial_core.sv
 M ../../../../rtl/apb_uart_sva.sv
 M ../../../../rtl/async_fifo.sv
 M ../../../../rtl/uart_tx.sv
 M ../../../../rtl_filelist.f
 M ../../../../scripts/merge_coverage.ps1
 M ../../../../scripts/run_acceptance.ps1
 M ../../../../scripts/run_architecture_check.ps1
 M ../../../../scripts/run_baud_mutation_check.ps1
 M ../../../../scripts/run_cdc_structural_check.ps1
 M ../../../../scripts/run_control_mutation_check.ps1
 M ../../../../scripts/run_fifo_mutation_check.ps1
 M ../../../../scripts/run_final_regression.ps1
 M ../../../../scripts/run_mutation_campaign.ps1
 M ../../../../scripts/run_mutation_check.ps1
 M ../../../../scripts/run_questa.ps1
 M ../../../../scripts/run_vivado_synth.ps1
 M ../../../../scripts/vivado_synth.tcl
 M ../../../../tb/interfaces/uart_probe_if.sv
 M ../../../../tb/top/tb_apb_uart.sv
 M ../../../../tb/uvm/apb_driver.svh
 M ../../../../tb/uvm/apb_monitor.svh
 M ../../../../tb/uvm/sequences/uart_base_reg_sequences.svh
 M ../../../../tb/uvm/sequences/uart_misc_sequences.svh
 M ../../../../tb/uvm/sequences/uart_reset_timing_sequences.svh
 M ../../../../tb/uvm/sequences/uart_rx_fifo_sequences.svh
 M ../../../../tb/uvm/tests/uart_base_reg_tests.svh
 M ../../../../tb/uvm/tests/uart_cdc_timing_tests.svh
 M ../../../../tb/uvm/uart_agent.svh
 M ../../../../tb/uvm/uart_coverage.svh
 M ../../../../tb/uvm/uart_driver.svh
 M ../../../../tb/uvm/uart_env.svh
 M ../../../../tb/uvm/uart_env_cfg.svh
 M ../../../../tb/uvm/uart_monitor.svh
 M ../../../../tb/uvm/uart_pkg.sv
 M ../../../../tb/uvm/uart_predictor.svh
 M ../../../../tb/uvm/uart_reg_model.svh
 M ../../../../tb/uvm/uart_rx_monitor.svh
 M ../../../../tb/uvm/uart_sequences.svh
 M ../../../../tb/uvm/uart_serial_cfg.svh
 M ../../../../tb/uvm/uart_tests.svh
 M ../../../../tb/uvm/uart_virtual_sequences.svh
?? ../../../../config/cdc_path_policy.psd1
?? ../../../../constraints/
?? ../../../../docs/p0_p1_finish_plan.md
?? ../../../../docs/p0_p1_finish_result.md
?? ../../../../docs/p0_p2_contract_closure.md
?? ../../../contract_tests.json
?? ../../../evidence_gate_selftests.json
?? ../../../fifo_unit_tests.json
?? ../../../final_regression/coverage/functional_assertion_gate.json
?? ../../../final_regression/seed_401_summary.md
?? ../../../final_regression/seed_501_summary.md
?? ../../../final_regression/seed_601_summary.md
?? ../../../final_regression/source_manifest.json
?? ../../../parameter_regression/
?? ../../../regression_summary.json
?? ../../../stress/
?? ../../../synthesis/bus_skew.rpt
?? ../../../synthesis/cdc_review.json
?? ../../../synthesis/exceptions.rpt
?? ../../../../rtl/tx_completion_cdc.sv
?? ../../../../scripts/check_cdc_paths.ps1
?? ../../../../scripts/evidence_common.ps1
?? ../../../../scripts/run_contract_tests.ps1
?? ../../../../scripts/run_fifo_unit_tests.ps1
?? ../../../../scripts/run_parameter_regression.ps1
?? ../../../../scripts/test_evidence_gates.ps1
?? ../../../../tb/unit/
?? ../../../../tb/uvm/sequences/uart_completion_sequences.svh
?? ../../../../tb/uvm/tests/uart_completion_tests.svh
?? ../../../../tb/uvm/uart_config_checker.svh
```
