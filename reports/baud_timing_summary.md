# BAUD Timing Summary

- Date: `2026-07-13`
- Test: `uart_baud_timing_test`
- Pattern: `0x55`

测试不读取 DUT 内部的 `bit_tick`。checker 先测量实际 `uart_clk` 周期，再从 `tx_o` 的起始位下降沿开始，连续测量 9 个相邻帧位边界。

| UART clock period | BAUD register | Effective divisor | Expected/measured bit width | Result |
| ---: | ---: | ---: | ---: | --- |
| 40 ns | 0 | 1 | 40 ns | PASS |
| 40 ns | 1 | 1 | 40 ns | PASS |
| 40 ns | 4 | 4 | 160 ns | PASS |
| 40 ns | 8 | 8 | 320 ns | PASS |
| 26 ns | 0 | 1 | 26 ns | PASS |
| 26 ns | 1 | 1 | 26 ns | PASS |
| 26 ns | 4 | 4 | 104 ns | PASS |
| 26 ns | 8 | 8 | 208 ns | PASS |

两组运行均为 0 warning、0 error、0 fatal。`baud_timing_cg` 对 BAUD=0/1/4/8 及测量通过结果的交叉覆盖为 100%。本项目约定 BAUD 在帧间更新；传输过程中改变 BAUD 不属于当前支持范围。
