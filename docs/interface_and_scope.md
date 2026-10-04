# Interface Contract and Verification Scope

## Verification Target

This is a verification-focused SystemVerilog/UVM learning project. The DUT
combines zero-wait-state APB registers, asynchronous TX/RX FIFOs, and a
fixed-8N1 serial model. It is not a production UART IP.

The serial model does not implement 16x oversampling, parity, configurable
stop bits, or standard-baud-rate error analysis. FPGA board-level serial
operation has not been demonstrated. The detailed requirements are in
[requirements and scope (Chinese)](requirements_and_scope.md).

## Register and Reset Contract

Addresses, bit definitions, and reset values are defined in
[apb_uart_reg_pkg.sv](../rtl/apb_uart_reg_pkg.sv).

- Normal configuration changes require TX_BUSY and CFG_BUSY to clear, with
  the external RX peer idle. The configuration handshake does not establish
  that an external frame has finished.
- Disable aborts an active frame; reset discards queued and active data.
  Clearing busy through either operation does not prove successful delivery.
- TX_EMPTY describes the FIFO; TX_BUSY also includes a frame still being
  transmitted. See the [TX completion case](tx_completion_case.md#english).
- CDC checks and out-of-context synthesis are documented; they are not
  commercial CDC signoff, place-and-route timing, or board measurements.

The [architecture](architecture_figures.md) shows the data path, configuration
crossing, reset distribution, and verification connections.

## Tool Compatibility

| Route | Recorded setup and scope |
| --- | --- |
| Standalone FIFO smoke | Icarus 12.0 on Ubuntu 24.04/WSL; Bash and GNU coreutils. Runs the reference-queue test and two fault-detection checks. |
| UVM simulation | Windows, PowerShell 7, ModelSim SE-64 10.4, bundled UVM 1.1d, and a valid license supporting SystemVerilog, UVM, SVA and coverage. |
| Synthesis/full acceptance | Includes Vivado; recorded version 2023.2. |

Other commercial simulator versions have not been validated here. The full
UVM environment has not been validated with Icarus or Verilator. Icarus skips
four unsupported inline FIFO SVA; those assertions remain enabled in the
ModelSim/Questa flow. The homepage CI badge covers only the FIFO workflow.

## Reading the Results

The homepage numbers refer to saved run `20260913_134519_8d9500ab` on
**2026-09-13**, with source identity in the
[run manifest](../reports/published/20260913_134519_8d9500ab/acceptance_summary.json).
They are not a claim that every later commit reran the full acceptance suite.

The 69/69 bin result describes the declared functional coverage model, not all
possible UART behavior. The 13/13 fault result covers the declared mutation
list, each paired with a passing baseline. Two injected faults in the free
FIFO smoke are separate checks, not additions to that historical campaign.

The [2026-10-04 loopback sample](../examples/loopback/README.md) has its own
manifest, VCD and log. Its compact preview shows serial TX timing; it is not
an APB completion-edge timing trace.

Lightweight JSON summaries and result tables are committed. Full raw logs,
UCDB/HTML reports, and delivery bundles are local artifacts, not downloadable
release assets. Follow [reproduction and delivery](reproduction_and_delivery.md)
to generate and verify a bundle.

[Back to the homepage](../README.md) · [Documentation index](README.md)
