# RTL-only Coverage Gate

- Time: `2026-09-13 12:07:16`
- Result: **PASS**
- Source: `reports\final_regression\coverage\dut_bydu_coverage.txt`

| RTL module | Metric | Minimum | Actual | Waiver | Result |
| --- | --- | ---: | ---: | --- | --- |
| `tx_completion_cdc` | Statements | 95% | 100% | - | PASS |
| `tx_completion_cdc` | Branches | 90% | 100% | - | PASS |
| `apb_uart` | Statements | 95% | 100% | - | PASS |
| `apb_uart_regs` | Statements | 95% | 100% | - | PASS |
| `apb_uart_regs` | Branches | 90% | 100% | - | PASS |
| `apb_uart_cfg_cdc` | Statements | 95% | 100% | - | PASS |
| `apb_uart_cfg_cdc` | Branches | 90% | 100% | - | PASS |
| `apb_uart_serial_core` | Statements | 95% | 100% | - | PASS |
| `uart_baud_gen` | Statements | 95% | 100% | - | PASS |
| `uart_baud_gen` | Branches | 85% | 85.7% | RTL-COV-W004 | PASS |
| `async_fifo` | Statements | 95% | 100% | - | PASS |
| `async_fifo` | Branches | 95% | 100% | - | PASS |
| `reset_sync` | Statements | 100% | 100% | - | PASS |
| `uart_rx` | Statements | 95% | 95.6% | - | PASS |
| `uart_rx` | Branches | 90% | 94.1% | - | PASS |
| `uart_rx` | FSM | 85% | 100% | - | PASS |
| `uart_tx` | Statements | 95% | 96.4% | - | PASS |
| `uart_tx` | Branches | 90% | 92.8% | - | PASS |
| `uart_tx` | FSM | 95% | 100% | - | PASS |

## Waivers

- **RTL-COV-W001**（RTL toggle coverage）：宽寄存器和总线高位在固定8N1教学场景中没有逐位翻转要求，toggle仅作观察指标。
- **RTL-COV-W002**（uart_tx/uart_rx defensive default transitions）：枚举状态机的非法状态需要人为破坏编码，不属于正常功能回归。
- **RTL-COV-W003**（short-circuit condition combinations）：无独立功能含义的短路真值组合不设门禁，由功能覆盖、分支和断言补充说明。
- **RTL-COV-W004**（uart_baud_gen divisor zero defensive branch）：APB寄存器层会把BAUD=0规范化为1，因此集成回归无法把0送到波特率子模块；保留子模块本地防御并将唯一不可达分支显式豁免。
