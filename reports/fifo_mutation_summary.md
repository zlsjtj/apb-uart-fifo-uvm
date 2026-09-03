# FIFO Control Mutation Summary

- Time: `2026-09-03 17:42:13`
- Mutation: force FIFO full flag low (`UART_MUTATE_FIFO_FULL_STUCK_LOW`)
- Test: `uart_rx_fifo_full_test`
- Seed: `91`
- Isolated simulation library: `work_fifo_mutation`
- FIFO checker reported a failure: `True`
- Result: **PASS (mutation detected)**
- Log: `logs/mutation_fifo_full_stuck_low_91.log`

This script passes only when the injected FIFO-control fault is detected.
