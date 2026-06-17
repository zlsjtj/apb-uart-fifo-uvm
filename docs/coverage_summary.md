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

## Regression Coverage Intent

The current regression is aimed at these scenarios:

| Scenario | Test |
| --- | --- |
| Register reset and read/write | `uart_reg_test` |
| Illegal APB address and read-only write | `uart_reg_test`, `uart_bad_access_test` |
| APB TX write to UART TX output | `uart_loopback_test`, `uart_random_test` |
| UART loopback to APB RX readback | `uart_loopback_test`, `uart_random_test` |
| External RX frame input | `uart_external_rx_test` |
| TX FIFO full / overflow path | `uart_fifo_full_test` |
| Empty RXDATA read / underflow path | `uart_bad_access_test` |
| Disable and re-enable recovery | `uart_recover_test` |

## Current Limitation

The script saves per-test UCDB files under `reports/`, but this repository does
not yet merge those files into a single coverage database or export an HTML
coverage report. The next practical step is to add a merge/report script once
the simulator environment and license options are stable.
