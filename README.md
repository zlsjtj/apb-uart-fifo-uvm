# APB UART FIFO UVM Lab

This repository is a small SystemVerilog/UVM verification lab for an
APB-controlled UART model with asynchronous FIFO buffers.

The goal is to show a complete but still understandable verification flow:
RTL, interfaces, UVM agents, scoreboard, coverage, directed/random tests,
regression scripts, and a short set of notes about what was checked.

## Directory Layout

```text
rtl/                DUT and SVA
tb/interfaces/      APB and UART interfaces
tb/uvm/             UVM items, agents, env, predictor, scoreboard, coverage
tb/uvm/sequences/   Feature-oriented APB/UART sequences
tb/uvm/tests/       Feature-oriented UVM tests
tb/top/             Simulation top
scripts/            Local regression entry points
reports/            Regression summary and sample logs
docs/               Verification and coverage notes
```

## Register Map

寄存器地址、复位值和位定义统一放在 `rtl/apb_uart_reg_pkg.sv`。RTL、SVA、
UVM sequence 和寄存器模型都引用同一份定义，避免后续修改时出现地址不一致。

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | CTRL | bit0 enable, bit1 loopback, bit2 irq_en |
| `0x04` | STATUS | FIFO empty/full, frame error, irq state |
| `0x08` | BAUD | Read/write configuration register |
| `0x0c` | TXDATA | Write TX FIFO |
| `0x10` | RXDATA | Read RX FIFO |

## Model Scope

This is a verification practice DUT, not a production UART IP.

- `BAUD` controls a simplified UART bit tick in the `uart_clk` domain.
- UART TX/RX still use a simple tick-based serial model. There is no 16x
  oversampling, parity, or configurable stop-bit support.
- APB uses a zero-wait-state `pready=1` response.
- External resets assert asynchronously. Each APB/UART/FIFO reset is released
  through a two-stage synchronizer in its destination clock domain.
- Functional coverage is implemented in UVM covergroups, but merged UCDB/HTML
  reporting is generated from the current regression summary.

## Run

On Windows with ModelSim/Questa in `PATH`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1
```

Run a smaller subset:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_reg_test,uart_loopback_test
```

Run the reset/CDC test with a non-integer clock ratio and shifted phases:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 `
  -Tests uart_reset_cdc_test -Seed 52 `
  -PclkHalfNs 7 -UartHalfNs 11 -PclkPhaseNs 2 -UartPhaseNs 5
```

Capture a VCD for the loopback path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2 -DumpLoopbackVcd
```

The VCD is written under `reports/` and is ignored by git.

Merge coverage for the exact tests listed in the latest regression summary:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/merge_coverage.ps1
```

Text reports are written under `reports/coverage/`; the generated HTML entry
point is `reports/coverage/html/index.html`.

Run the isolated TX-data mutation check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_mutation_check.ps1
```

This command passes only when the injected bit error is reported by the
scoreboard. It uses `work_mutation` and does not replace the normal simulation
library. See [`docs/bug_closure_case.md`](docs/bug_closure_case.md).

Run the isolated IRQ-control mutation check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_control_mutation_check.ps1
```

This check forces IRQ low in a separate simulation library and passes only
when the IRQ test or assertion reports the injected fault.

Run all four mutation cases and generate a mutation matrix:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_mutation_suite.ps1
```

Run the complete local acceptance flow:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_acceptance.ps1
```

The acceptance flow combines structural audits, the three-seed regression,
two skewed-clock stress subsets, coverage merge, and all mutation cases.

Run the register-model structural audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_reg_model_check.ps1
```

Run the P2 verification-architecture audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_p2_structural_check.ps1
```

Freeze the three-seed final evidence package (48 simulations plus merged UCDB):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_final_regression.ps1
```

The package is written to `reports/final_regression/` and includes per-seed
summaries, source SHA-256 values, coverage reports, and a reproducibility
manifest. See [`docs/final_regression_evidence.md`](docs/final_regression_evidence.md).

Run the CDC structural audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_cdc_structural_check.ps1
```

The audit checks project CDC structures and writes
`reports/cdc_structural_summary.md`. It does not replace commercial CDC signoff;
see [`docs/cdc_analysis.md`](docs/cdc_analysis.md).

## Tests

| Test | Main check |
| --- | --- |
| `uart_reg_test` | Reset values, register read/write, illegal access |
| `uart_config_latency_test` | APB configuration-write time versus UART-domain apply time |
| `uart_ral_test` | RAL access policy, frontdoor access, passive prediction, reset mirror |
| `uart_loopback_test` | APB TX write, UART loopback, APB RX readback |
| `uart_baud_loopback_test` | Loopback with `BAUD=4` to check bit tick timing |
| `uart_baud_timing_test` | Independent TX bit-width checks for BAUD=0/1/4/8 |
| `uart_irq_test` | IRQ enable/disable, pending RX data, assert and clear behavior |
| `uart_frame_error_test` | Bad stop-bit rejection, frame-error status, and recovery |
| `uart_external_rx_test` | External UART RX frame and APB readback |
| `uart_external_rx_baud_test` | External RX at `BAUD=4` with an independently timed, phase-offset BFM |
| `uart_rx_fifo_full_test` | RX FIFO full, extra-frame drop, drain, and recovery |
| `uart_reset_cdc_test` | Mid-traffic dual reset, independent resets, and recovery |
| `uart_fifo_full_test` | TX FIFO full and overflow error path |
| `uart_bad_access_test` | TXDATA read, RXDATA empty/read-only errors, bad address |
| `uart_random_test` | Random data, random gaps, status interleaving |
| `uart_recover_test` | Disable and re-enable recovery path |

Latest local result: [`reports/regression_summary.md`](reports/regression_summary.md)

Sample loopback log excerpt:
[`reports/sample_logs/uart_loopback_test_2.log`](reports/sample_logs/uart_loopback_test_2.log)

## Notes

- Coverage notes: [`docs/coverage_summary.md`](docs/coverage_summary.md)
- Coverage closure: [`docs/coverage_closure.md`](docs/coverage_closure.md)
- Debug notes: [`docs/debug_notes.md`](docs/debug_notes.md)
- Mutation case: [`docs/bug_closure_case.md`](docs/bug_closure_case.md)
- Final regression evidence: [`docs/final_regression_evidence.md`](docs/final_regression_evidence.md)
- CDC analysis: [`docs/cdc_analysis.md`](docs/cdc_analysis.md)
- Register model: [`docs/register_model.md`](docs/register_model.md)
- P2 verification architecture: [`docs/p2_verification_architecture.md`](docs/p2_verification_architecture.md)
- Architecture optimization: [`docs/architecture_optimization.md`](docs/architecture_optimization.md)
- Architecture closure and diagrams: [`docs/verification_architecture_closure.md`](docs/verification_architecture_closure.md)
