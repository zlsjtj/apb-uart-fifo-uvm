# Mutation Matrix

- Time: `2026-09-03 17:42:20`
- Mutants killed: `4/4`
- Mutation score: `100%`
- Elapsed seconds: `28.4`

| Mutation | Test | Seed | Primary detector | Result |
| --- | --- | ---: | --- | --- |
| TX data bit inversion | `uart_loopback_test` | 71 | `SB_TX_MISMATCH` | KILLED |
| IRQ stuck low | `uart_irq_test` | 81 | `IRQ_STATUS / irq_matches_rx_state` | KILLED |
| FIFO full stuck low | `uart_rx_fifo_full_test` | 91 | `RX_FIFO_FULL / SB_RX_MISMATCH` | KILLED |
| Baud tick stuck fast | `uart_baud_timing_test` | 96 | `BAUD_TIMING` | KILLED |

The score applies only to the four deliberately selected fault models; it is not a claim of exhaustive mutation coverage.
