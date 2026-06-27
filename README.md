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
tb/uvm/             UVM items, agents, env, scoreboard, coverage, tests
tb/top/             Simulation top
scripts/            Local regression entry points
reports/            Regression summary and sample logs
docs/               Verification and coverage notes
```

## Register Map

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
- Functional coverage is implemented in UVM covergroups, but merged UCDB/HTML
  reporting is still listed as follow-up work.

## Run

On Windows with ModelSim/Questa in `PATH`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1
```

Run a smaller subset:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_reg_test,uart_loopback_test
```

Capture a VCD for the loopback path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2 -DumpLoopbackVcd
```

The VCD is written under `reports/` and is ignored by git.

## Tests

| Test | Main check |
| --- | --- |
| `uart_reg_test` | Reset values, register read/write, illegal access |
| `uart_loopback_test` | APB TX write, UART loopback, APB RX readback |
| `uart_baud_loopback_test` | Loopback with `BAUD=4` to check bit tick timing |
| `uart_external_rx_test` | External UART RX frame and APB readback |
| `uart_fifo_full_test` | TX FIFO full and overflow error path |
| `uart_bad_access_test` | TXDATA read, empty RXDATA read, bad write address |
| `uart_random_test` | Random data, random gaps, status interleaving |
| `uart_recover_test` | Disable and re-enable recovery path |

Latest local result: [`reports/regression_summary.md`](reports/regression_summary.md)

Sample loopback log excerpt:
[`reports/sample_logs/uart_loopback_test_2.log`](reports/sample_logs/uart_loopback_test_2.log)

## Notes

- Coverage notes: [`docs/coverage_summary.md`](docs/coverage_summary.md)
- Debug notes: [`docs/debug_notes.md`](docs/debug_notes.md)
