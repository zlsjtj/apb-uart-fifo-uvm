# Reset/CDC Test Summary

- Date: `2026-09-03`
- Test: `uart_reset_cdc_test`

| Seed | pclk half/phase | uart_clk half/phase | Result | UVM warning/error/fatal |
| ---: | --- | --- | --- | --- |
| 401 | 5 ns / 0 ns | 20 ns / 0 ns | PASS | 0 / 0 / 0 |
| 411 | 7 ns / 2 ns | 11 ns / 5 ns | PASS | 0 / 0 / 0 |
| 421 | 9 ns / 4 ns | 13 ns / 7 ns | PASS | 0 / 0 / 0 |

每组配置都执行了传输过程中双复位、APB 单独复位、UART 单独复位，以及复位后的 loopback 恢复检查。scoreboard 每次都记录 3 次 reset flush，恢复阶段检查 TX=3、RX=3。

`reset_cg` 在正式回归 UCDB 中为 100%，APB-only、UART-only 和双复位三个 bin 均已命中。RTL 已改为各目标域异步断言、两级同步释放，并增加 8 条复位断言和 4 条释放 cover property；这里记录的仍是动态仿真结果，不能替代专用 CDC/RDC 工具和时序约束检查。
