# Mutation Check Summary

- Time: `2026-09-02 23:59:39`
- Mutation: invert TX FIFO write-data bit 0 (`UART_MUTATE_TX_LSB`)
- Test: `uart_loopback_test`
- Seed: `71`
- Isolated simulation library: `work_mutation`
- Scoreboard reported `SB_TX_MISMATCH`: `True`
- Result: **PASS (mutation detected)**
- Log: `logs/mutation_tx_lsb_71.log`

This script passes only when the known injected fault is detected.
