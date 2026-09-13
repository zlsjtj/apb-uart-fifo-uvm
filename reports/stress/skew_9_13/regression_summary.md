# Regression Summary

- Simulator: `questa`
- Time: `2026-09-13 12:12:54`
- FIFO address width: 4; white-box enabled: True
- Clock config: `pclk_half=9ns pclk_phase=4ns uart_half=13ns uart_phase=1ns`

| Test | Seed | Status | Errors | Fatals | Warnings | Log |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| uart_tx_completion_test | 751 | PASS | 0 | 0 | 0 | `logs/uart_tx_completion_test_751.log` |
| uart_config_latency_test | 752 | PASS | 0 | 0 | 0 | `logs/uart_config_latency_test_752.log` |
| uart_config_stress_test | 753 | PASS | 0 | 0 | 0 | `logs/uart_config_stress_test_753.log` |
| uart_frame_error_test | 754 | PASS | 0 | 0 | 0 | `logs/uart_frame_error_test_754.log` |
| uart_external_rx_baud_test | 755 | PASS | 0 | 0 | 0 | `logs/uart_external_rx_baud_test_755.log` |
| uart_rx_fifo_full_test | 756 | PASS | 0 | 0 | 0 | `logs/uart_rx_fifo_full_test_756.log` |
| uart_reset_cdc_test | 757 | PASS | 0 | 0 | 0 | `logs/uart_reset_cdc_test_757.log` |
| uart_frame_reset_test | 758 | PASS | 0 | 0 | 0 | `logs/uart_frame_reset_test_758.log` |

Passed 8/8 tests.
