# Regression Summary

- Simulator: `questa`
- Time: `2026-09-13 12:10:20`
- FIFO address width: 6; white-box enabled: True
- Clock config: `pclk_half=5ns pclk_phase=0ns uart_half=20ns uart_phase=0ns`

| Test | Seed | Status | Errors | Fatals | Warnings | Log |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| uart_tx_completion_test | 8001 | PASS | 0 | 0 | 0 | `logs/uart_tx_completion_test_8001.log` |
| uart_fifo_wrap_test | 8002 | PASS | 0 | 0 | 0 | `logs/uart_fifo_wrap_test_8002.log` |
| uart_fifo_full_test | 8003 | PASS | 0 | 0 | 0 | `logs/uart_fifo_full_test_8003.log` |
| uart_rx_fifo_full_test | 8004 | PASS | 0 | 0 | 0 | `logs/uart_rx_fifo_full_test_8004.log` |
| uart_reset_cdc_test | 8005 | PASS | 0 | 0 | 0 | `logs/uart_reset_cdc_test_8005.log` |
| uart_frame_reset_test | 8006 | PASS | 0 | 0 | 0 | `logs/uart_frame_reset_test_8006.log` |

Passed 6/6 tests.
