# Coverage Summary

This project currently has functional coverage in `tb/uvm/uart_coverage.svh`.
The covergroups are meant to check that the regression touches the main APB
register paths and representative UART data values.

## Implemented Covergroups

`apb_cg` samples APB monitor transactions:

- address bins for `CTRL`, `STATUS`, `BAUD`, `TXDATA`, `RXDATA`, and bad
  addresses
- read/write direction bins
- `pslverr` ok/error bins
- data bins for `0x00`, `0xff`, low, mid, and high ranges
- crosses for address vs direction and address vs error

`uart_cg` samples UART frames observed by the UART monitor:

- `0x00`
- `0xff`
- remaining byte values

`status_irq_cg` samples successful STATUS reads:

- IRQ disabled/enabled with RX FIFO empty
- IRQ disabled/enabled with RX data pending
- IRQ low-to-high and high-to-low transitions

`status_error_cg` samples the frame-error path:

- clean RX FIFO before injection
- bad frame reported while RX FIFO remains empty and IRQ stays low
- clean recovery frame accepted with IRQ asserted
- frame-error detection and clear transitions

`status_fifo_cg` samples RX FIFO boundary behavior:

- empty, partially occupied and full states
- RX full assertion and clear transitions

`reset_cg` samples reset control:

- APB-only reset
- UART-only reset
- both domains reset together

## Regression Coverage Intent

The current regression is aimed at these scenarios:

| Scenario | Test |
| --- | --- |
| Register reset and read/write | `uart_reg_test` |
| BAUD-controlled loopback timing | `uart_baud_loopback_test` |
| Independent TX bit-width measurement | `uart_baud_timing_test` |
| IRQ enable, pending data, assertion and clear | `uart_irq_test` |
| Bad stop bit, rejected data, and normal-frame recovery | `uart_frame_error_test` |
| Illegal APB address and read-only write | `uart_reg_test`, `uart_bad_access_test` |
| APB TX write to UART TX output | `uart_loopback_test`, `uart_random_test` |
| UART loopback to APB RX readback | `uart_loopback_test`, `uart_random_test` |
| External RX frame input | `uart_external_rx_test` |
| RX FIFO full, drop, drain and recovery | `uart_rx_fifo_full_test` |
| Dual/independent reset and recovery | `uart_reset_cdc_test` |
| TX FIFO full / overflow path | `uart_fifo_full_test` |
| Empty RXDATA read / underflow path | `uart_bad_access_test` |
| Disable and re-enable recovery | `uart_recover_test` |

## IRQ Coverage Check

The `uart_irq_test` UCDB was checked with `vcover report -details -cvg` after
the 2026-07-12 regression. Its `status_irq_cg` reached 100%: all four planned
IRQ/RX-empty states and both IRQ assertion/clear transitions were covered.
The complete 13-test regression is now merged by `scripts/merge_coverage.ps1`.

## Frame-error Coverage Check

The `uart_frame_error_test` UCDB was checked after the 2026-07-12 regression.
Its `status_error_cg` reached 100%: the clean-empty, bad-frame-rejected and
recovered-with-data states were all hit, together with frame-error detection
and clear transitions. The test also checks that the bad byte is not queued,
IRQ stays low, and a later valid frame is accepted.

## RX FIFO Boundary Coverage Check

The `uart_rx_fifo_full_test` fills the 16-byte RX FIFO, sends one extra frame,
drains the accepted bytes in order and then sends a recovery byte. Its
`status_fifo_cg` reached 100% in the 2026-07-12 run: empty, partial and full
states were observed, together with RX-full assertion and clear transitions.
The scoreboard recorded one expected full-FIFO drop and no leftover data.

## Reset/CDC Coverage Check

`uart_reset_cdc_test` was run with the default clocks and two non-integer clock
ratios. Each run covered a reset while TX data was pending, APB-only reset,
UART-only reset and post-reset loopback recovery. `reset_cg` reached 100% for
the APB-only, UART-only and combined reset bins. The exact clock settings and
results are recorded in `reports/reset_cdc_summary.md`.

## BAUD Timing Coverage Check

`uart_baud_timing_test` measures `tx_o` transitions directly and does not use
the DUT's `bit_tick`. BAUD=0/1/4/8 were checked with 40 ns and 26 ns UART clock
periods. All measured bit widths matched `effective_divisor * uart_period`, and
the test-local `baud_timing_cg` reached 100%. Results are recorded in
`reports/baud_timing_summary.md`.

## Merged Regression Result

The 2026-09-03 final merge contains exactly the 39 PASS rows from base seeds
101, 201, and 301. Functional coverage is 100% (65/65 planned bins), all 40
assertions were attempted with zero failures, and all 13 cover directives were
hit. DUT code metrics and waivers are documented in
`docs/coverage_closure.md`; generated text and HTML reports are under
`reports/coverage/`.
