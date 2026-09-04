# Mutation Campaign

- Time: `2026-09-04 23:54:39`
- Result: **PASS**
- Mutants killed: `11/11`
- Mutation score: `100%`

| Fault model | Define | Test | Seed | Detector | Result |
| --- | --- | --- | ---: | --- | --- |
| TX 数据位翻转 | `UART_MUTATE_TX_LSB` | `uart_loopback_test` | 71 | `SB_TX_MISMATCH|LOOPBACK` | KILLED |
| IRQ 恒低 | `UART_MUTATE_IRQ_STUCK_LOW` | `uart_irq_test` | 81 | `IRQ_STATUS|irq_matches_rx_state` | KILLED |
| RX FIFO full 恒低 | `UART_MUTATE_FIFO_FULL_STUCK_LOW` | `uart_rx_fifo_full_test` | 91 | `RX_FIFO_FULL|SB_RX_MISMATCH|rx_full_blocks_write` | KILLED |
| 波特率 tick 过快 | `UART_MUTATE_BAUD_TICK_FAST` | `uart_baud_timing_test` | 96 | `BAUD_TIMING` | KILLED |
| RX 数据位翻转 | `UART_MUTATE_RX_LSB` | `uart_external_rx_test` | 1011 | `SB_RX_MISMATCH|EXT_RX` | KILLED |
| RX FIFO empty 恒高 | `UART_MUTATE_RX_EMPTY_STUCK_HIGH` | `uart_external_rx_test` | 1012 | `EXT_RX|SB_RX_LEFT|SEQ_EXP_ERR` | KILLED |
| 配置 apply 丢失 | `UART_MUTATE_CFG_APPLY_DROP` | `uart_config_latency_test` | 1013 | `CFG_LATENCY|config_changes_only_on_apply` | KILLED |
| 配置 ack 恒定 | `UART_MUTATE_CFG_ACK_STUCK` | `uart_config_latency_test` | 1014 | `CFG_LATENCY|config_request_eventually_ack` | KILLED |
| IRQ 恒高 | `UART_MUTATE_IRQ_STUCK_HIGH` | `uart_irq_test` | 1015 | `IRQ_STATUS|irq_matches_rx_state` | KILLED |
| 帧错误被屏蔽 | `UART_MUTATE_FRAME_ERR_MASK` | `uart_frame_error_test` | 1016 | `FRAME_REJECT|FRAME_SETUP|frame_error_seen` | KILLED |
| 复位直接释放 | `UART_MUTATE_RESET_RELEASE_DIRECT` | `uart_reset_cdc_test` | 1017 | `reset_release_has_sync_latency` | KILLED |

该分数只覆盖表中声明的代表性故障，不表示所有 RTL 缺陷都能被检出。
