# APB UART FIFO UVM

[![FIFO smoke (Icarus)](https://github.com/zlsjtj/apb-uart-fifo-uvm/actions/workflows/fifo-smoke.yml/badge.svg?branch=main)](https://github.com/zlsjtj/apb-uart-fifo-uvm/actions/workflows/fifo-smoke.yml)

A SystemVerilog/UVM verification example for an APB UART with two clock domains
and asynchronous TX/RX FIFOs. Follow a byte from an APB write to the serial pin
and back, then test what happens when a FIFO fills, a frame is malformed, or
one clock domain resets.

[Run an example](#choose-a-run) · [Follow one byte](#follow-one-byte-through-uvm) ·
[Debugging case](docs/bug_closure_case.md#english) · [中文入门](docs/quickstart.md)

One case worth reading: [an APB regression passed because the DUT and its testbench shared the same sampling mistake](docs/bug_closure_case.md#english).

The DUT is a simplified, fixed-8N1 teaching model. It has no 16x oversampling,
parity, or configurable stop bits. The project focuses on verification;
board-level serial operation has not been demonstrated.

## A Real Loopback Run

<img src="examples/loopback/byte-preview.png" width="540" alt="The second recorded byte, 0x55: APB write and read values match the serial TX frame from 1.26 to 1.66 microseconds. Serial data bits 0 through 7 are sent least significant bit first.">

`uart_loopback_test`, seed 2, recorded **2026-10-04**: six bytes
(`00 55 aa ff 13 37`) sent and read back. The preview follows the second byte,
`0x55`; its time axis shows serial TX only, not APB transfer timing.
[Full waveform, VCD, log, and plot scripts](examples/loopback/README.md).

## Choose a Run

| Route | Tools | Scope |
| --- | --- | --- |
| Free FIFO smoke | Ubuntu/WSL, Icarus 12.0, Bash, GNU coreutils | Standalone reference-queue test, no UVM or SVA |
| UVM loopback | Windows, PowerShell 7, licensed ModelSim/Questa | APB/UART agents, predictor, scoreboard, assertions |

### Free FIFO Smoke

On Ubuntu 24.04 or Ubuntu in WSL, the FIFO test needs no commercial simulator:

```bash
sudo apt-get update
sudo apt-get install -y iverilog
git clone https://github.com/zlsjtj/apb-uart-fifo-uvm.git
cd apb-uart-fifo-uvm
bash scripts/run_fifo_smoke.sh
```

This runs the existing reference-queue test at four FIFO depths and two clock
ratios, then checks that a stuck-low full flag and corrupted read data are
detected. It was tested with Icarus 12.0. Logs go into a new directory under
`work_fifo_smoke/run.*`; success ends with:

```text
FIFO smoke: 8/8 baselines passed; 2/2 injected faults detected.
```

This is a FIFO test, not the UVM regression. Icarus skips the four inline FIFO
SVA it cannot parse; those remain enabled in ModelSim/Questa. The
[GitHub Actions workflow](.github/workflows/fifo-smoke.yml) runs the same script
and retains its logs. The [2026-10-04 cloud run for `d4d72f3`](https://github.com/zlsjtj/apb-uart-fifo-uvm/actions/runs/37186769748)
passed. The badge above reports this FIFO workflow only, not the UVM regression.

### UVM Loopback

Use Windows, PowerShell 7 (`pwsh`), and a licensed ModelSim/Questa installation
with SystemVerilog, UVM, assertions, and coverage support. The recorded run used
ModelSim SE-64 10.4 with its bundled UVM 1.1d. Other simulator versions have not
been validated here. Vivado is only needed for the synthesis/full acceptance flow.

```powershell
git clone https://github.com/zlsjtj/apb-uart-fifo-uvm.git
cd apb-uart-fifo-uvm
# Skip this line if vlib, vlog, vsim and vcover are already on PATH.
$env:APB_UART_QUESTA_BIN = 'C:\modeltech64_10.4\win64'
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2 -DumpLoopbackVcd
```

Change the simulator path to your installation. A successful run writes
`Passed 1/1 tests.` to `reports/regression_summary.md` and produces:

- `logs/uart_loopback_test_2.log`: transactions and scoreboard results.
- `reports/uart_loopback_test_2.vcd`: APB and serial signals for a waveform viewer.
- `reports/uart_loopback_test_2.ucdb`: this test's coverage database.

The script compiles the design and testbench; no prebuilt `work` library is
required. Generated logs, waveforms, and UCDB files stay local. For setup errors,
test selection, and coverage commands, see the [quick start](docs/quickstart.md).
Without the simulator, inspect the [recorded log and VCD](examples/loopback/README.md).

## Follow One Byte Through UVM

1. **Sequence:** [uart_loopback_seq](tb/uvm/sequences/uart_functional_sequences.svh)
   configures loopback, writes six TXDATA bytes, then reads RXDATA.
2. **Driver:** [apb_driver](tb/uvm/apb_driver.svh) turns each item into an APB
   transfer and samples its response at the completion edge.
3. **Monitors:** [apb_monitor](tb/uvm/apb_monitor.svh) reports completed transfers;
   [uart_monitor](tb/uvm/uart_monitor.svh) observes the TX pin using configured
   bit timing, not the DUT's internal baud tick.
4. **Predictor:** [uart_predictor](tb/uvm/uart_predictor.svh) makes TX expectations
   from successful APB TXDATA writes. In loopback, RX expectations come from
   observed TX frames. In external-RX tests, they come from the
   [RX pin monitor](tb/uvm/uart_rx_monitor.svh), not the stimulus driver.
5. **Scoreboard:** [uart_scoreboard](tb/uvm/uart_scoreboard.svh) compares expected
   TX bytes with observed frames, and expected RX bytes with successful APB
   reads. Unconsumed expectations also fail the test.

The connections are in [uart_env.svh](tb/uvm/uart_env.svh), with an
[architecture overview](docs/architecture_figures.md). For a next test,
try `uart_frame_error_test` or `uart_fifo_wrap_test`; the default 20-test list
is in [verification_plan.psd1](config/verification_plan.psd1).

## A Passing Regression That Missed a Bug

The DUT used to update PRDATA and PSLVERR **after** the APB completion edge.
Both driver and monitor sampled 2 ns late, so they shared the same wrong
assumption. An independent test read BAUD as **0 at the edge, 16 later**.

The fix made responses valid before the edge and changed BFM sampling to
`input #1step`. An independent [APB test](tb/unit/apb_contract_tb.sv) checks the
contract; the `apb_late` mutation puts the defect back to test the detector.
[Read the case and reproduce the comparison](docs/bug_closure_case.md#english).
Another case covers [why FIFO empty is not TX complete](docs/tx_completion_case.md#english).

## Recorded Results

These are the saved results of run `20260913_134519_8d9500ab` on **2026-09-13**,
not the current CI result. The [run manifest](reports/published/20260913_134519_8d9500ab/acceptance_summary.json)
records the source SHA-256; the newer loopback sample has a separate
[source manifest](examples/loopback/manifest.json).

| Check | Recorded result | Evidence |
| --- | --- | --- |
| UVM regression | 60/60: 20 tests across three base seeds | [Regression summary](reports/published/20260913_134519_8d9500ab/reports/final_regression/final_regression_summary.json) |
| FIFO depth subsets | 24/24 across depths 2, 4, 16, 64 | [Parameter runs](reports/published/20260913_134519_8d9500ab/reports/parameter_regression/summary.json) |
| Deliberate RTL faults | 13/13 detected; matching baselines passed | [Mutation results](reports/published/20260913_134519_8d9500ab/reports/mutation_campaign.json) |
| Declared functional bins | 69/69 hit | [Coverage checks](reports/published/20260913_134519_8d9500ab/reports/final_regression/coverage/functional_assertion_gate.json) |

Bin counts describe the declared coverage model, not all possible UART behavior.
Fault detection covers the 13 declared mutations. See the
[full result table](reports/published/20260913_134519_8d9500ab/paper_results.md)
for assertions, RTL coverage checks, and synthesis results. Full raw logs,
UCDB/HTML, and delivery bundles are local artifacts, not downloadable release
assets. [Reproduction instructions](docs/reproduction_and_delivery.md) explain
how to generate and check a bundle.

## Interface and Limits

| Address | Register | Purpose |
| --- | --- | --- |
| `0x00` | CTRL | Enable, loopback, IRQ enable |
| `0x04` | STATUS | FIFO flags, IRQ, frame error, CFG_BUSY, TX_BUSY |
| `0x08` | BAUD | Simplified bit-tick divider |
| `0x0c` | TXDATA | Write a TX byte |
| `0x10` | RXDATA | Read an RX byte |

Bit definitions and reset values are in
[apb_uart_reg_pkg.sv](rtl/apb_uart_reg_pkg.sv). APB has zero wait states.
Normal configuration changes require TX_BUSY and CFG_BUSY to clear and the
external RX peer to stay idle. Disable aborts an active frame; reset discards
queued and active data. Neither operation clearing busy proves delivery.
CDC checks and out-of-context synthesis are documented, but are not commercial
CDC signoff or board timing results.

No project license has been selected yet; public source visibility is not a
grant of an open-source license.

## Report a Problem

Open an [issue](https://github.com/zlsjtj/apb-uart-fifo-uvm/issues) with the command,
commit, simulator version, seed, and first failing log message. Setup failures
and small reproducing tests are useful contributions. Please include a failing
case with behavioral fixes; see the [documentation index](docs/README.md) for
the relevant tests and reports.
