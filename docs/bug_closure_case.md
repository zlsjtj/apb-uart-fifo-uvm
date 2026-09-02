# 故障注入与检查器有效性

正常回归全部通过，只能说明当前实现没有触发现有检查器，并不能直接证明检查器真的能抓错。为避免验证环境“只会报通过”，本项目增加了一次受控故障注入。

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

本次运行中，6 个发送字节均触发 `SB_TX_MISMATCH`。例如期望 `0x55` 时实际发送为 `0x54`，期望 `0xaa` 时实际发送为 `0xab`。最终 UVM 共报告 18 个 error，其中包括 6 次 TX 数据不一致、6 次 RX 侧连带不一致和 6 次 loopback 读回不一致。

故障注入脚本判定为 `PASS (mutation detected)`，详细结果见 `reports/mutation_summary.md`。随后关闭故障注入开关重新执行 13 项正式回归，结果为 13/13 PASS，且 warning、error、fatal 均为 0。

## 4. 结论

这次实验说明 TX 数据比较并非形式上的日志统计：当 DUT 的数据路径发生一位错误时，monitor、scoreboard 和端到端读回检查都能给出失败结果。同时，故障版本与正常版本使用不同仿真库，不会污染正式回归证据。

本案例只证明了 TX 数据位错误能够被检出，不代表所有类型的设计缺陷都已覆盖。后续若继续扩展，可增加 FIFO 拒绝写失效、IRQ 漏报等 mutation，但没有必要为了数量重复制造相同类型的错误。
