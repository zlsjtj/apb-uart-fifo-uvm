# 故障注入与检查器有效性

正常回归全部通过，只能说明当前实现没有触发现有检查器，并不能直接证明检查器真的能抓错。为避免验证环境“只会报通过”，本项目保留了数据通路和控制通路两类受控故障注入。

## 1. 注入方法

在 `apb_uart.sv` 的 TX FIFO 写数据入口保留一个编译期开关 `UART_MUTATE_TX_LSB`。开关打开后，写入 FIFO 的数据最低位会被翻转；默认编译不开启该开关，DUT 行为不受影响。

故障版本使用独立的 `work_mutation` 仿真库，不覆盖正常回归使用的 `work` 库。执行命令如下：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_mutation_check.ps1
```

## 2. 预期结果

故障注入用例采用 `uart_loopback_test`，Seed 为 71。APB 侧写入的原始数据仍进入 scoreboard 期望队列，而 TX monitor 会观察到最低位已经翻转的数据，因此 scoreboard 应报告 `SB_TX_MISMATCH`。

这里的通过条件与普通回归相反：只有已知故障被明确检出，脚本才返回成功；如果仿真零报错，反而说明故障逃逸，脚本必须失败。

## 3. 实际结果

本次运行中，6 个发送字节均触发 `SB_TX_MISMATCH`。例如期望 `0x55` 时实际发送为 `0x54`，期望 `0xaa` 时实际发送为 `0xab`。最终 UVM 共报告 12 个 error，其中包括 6 次 TX 数据不一致和 6 次 loopback 读回不一致。RX predictor 以引脚上实际出现的帧建立 FIFO 期望，因此不会把同一处 TX mutation 重复记成 RX scoreboard 错误。

故障注入脚本判定为 `PASS (mutation detected)`，详细结果见 `reports/mutation_summary.md`。

第二类故障使用 `UART_MUTATE_IRQ_STUCK_LOW` 强制 IRQ 输出保持低电平，并在独立的 `work_irq_mutation` 库中运行 `uart_irq_test`（seed 81）。执行命令为：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_control_mutation_check.ps1
```

该故障同时被测试中的 `IRQ_STATUS` 检查和 `irq_matches_rx_state` 断言发现，脚本返回 `PASS (mutation detected)`；明细见 `reports/control_mutation_summary.md`。关闭两种故障开关后执行三组正式回归，结果为 45/45 PASS，且 warning、error、fatal 均为 0。

## 4. 结论

这次实验说明 TX 数据比较并非形式上的日志统计：当 DUT 的数据路径发生一位错误时，monitor、scoreboard 和端到端读回检查都能给出失败结果。同时，故障版本与正常版本使用不同仿真库，不会污染正式回归证据。

第三类故障在 `async_fifo.sv` 中使用 `UART_MUTATE_FIFO_FULL_STUCK_LOW` 强制 full 标志为低，并运行 `uart_rx_fifo_full_test`（seed 91）。该故障引起 full 状态缺失、FIFO 顺序错误和恢复失败，被 `RX_FIFO_FULL`、`RX_FIFO_ORDER` 与 `SB_RX_MISMATCH` 等检查发现。三项结果统一记录在 `reports/mutation_matrix.md`。

这三例分别证明了数据比较链路、IRQ 控制检查和 FIFO 边界检查能够抓到已知错误，不代表所有类型的设计缺陷都已覆盖。后续若继续扩展，应选择新的故障机理，没有必要为了数量重复制造相同类型的错误。
