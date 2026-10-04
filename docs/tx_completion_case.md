# TX Completion / 发送结束为什么不能只看 FIFO 空

[English](#english) · [中文](#chinese) · [Run the check / 运行对照](#reproduce)

<a id="english"></a>

## An Empty FIFO Can Still Have a Byte in Flight

When the transmitter removes the last byte from the FIFO, serial transmission
is only beginning. Software that treats TX_EMPTY as completion can change BAUD
or disable the UART before that byte finishes. Even a busy bit can clear too
early: the start of the stop bit is not the end of the full stop-bit interval.

The current design counts accepted TXDATA writes in the APB domain and completed
frames in the UART domain. The completion count advances after the full stop bit,
crosses back through a registered Gray code and two-stage synchronizer, and is
compared with the accepted count to generate TX_BUSY. The counter width is the
FIFO address width plus two. See [tx_completion_cdc.sv](../rtl/tx_completion_cdc.sv)
and the [data-path diagram](architecture_figures.md).

Queued and in-flight bytes remain busy. Normal reconfiguration waits for both
TX_BUSY and CFG_BUSY, writes the configuration, and waits for CFG_BUSY again.
The external protocol must keep RX idle. Disable explicitly aborts and reset
discards data: busy clearing after either operation is not proof of delivery.

### Check the Stop Bit Independently

`uart_tx_completion_test` finds a frame start on the public TX pin and calculates
the stop-bit interval from the declared clock and baud setting. It reads STATUS
during that interval, requires TX_BUSY to remain high, then polls for completion
and checks the loopback readback. The sequence is in
[uart_completion_sequences.svh](../tb/uvm/sequences/uart_completion_sequences.svh).

`UART_MUTATE_TX_EARLY_COMPLETE` deliberately reports completion at the start of
the stop bit. The campaign first runs a correct baseline with the same test and
seed. It counts the fault as `KILLED` only when the baseline passes and the mutant
produces an actual `TX_COMPLETION` error. Tool errors and timeouts do not count.

<a id="chinese"></a>

## 问题

TX FIFO 的最后一个字节被取走时，串行发送才刚开始。如果软件把 TX_EMPTY 当作发送结束，随后立即修改 BAUD 或关闭 UART，就可能截断还在发送的字节。

即使另加 busy 位，也要说明何时清零：输出停止位的上升沿只是停止位开始，不是整帧结束。接收端还需要一个完整位周期。

## 当前实现

APB 域对成功接受的 TXDATA 写计数，UART 域在完整停止位结束后对完成数计数。完成计数寄存为 Gray 码，经两级同步返回，与 APB 接收计数比较生成 TX_BUSY。计数宽度为 FIFO 地址宽度加 2，给最小 FIFO 与完成流水级留出余量。

刚写入、尚未传到 UART 域的数据已经计入 busy；停止位尚未结束的数据也仍在 busy 内。正常配置流程必须等待 TX_BUSY 和 CFG_BUSY 都为 0，再写配置，最后等 CFG_BUSY 清零。外部 RX 空闲仍由通信协议保证。

disable 是显式中止，reset 会丢弃在途和排队数据。因此这两种操作后的 busy 清零不代表数据成功送达。

## 怎样验证检查器确实能发现提前结束

uart_tx_completion_test 从公开 TX 引脚定位帧起点，根据声明的时钟与波特率计算停止位窗口，在停止位中间读 STATUS，要求 TX_BUSY 仍为 1；结束后轮询清零，并检查回环读回数据。

UART_MUTATE_TX_EARLY_COMPLETE 故意在停止位开始时报告完成。campaign 先运行同测试、同种子的正确基线，再运行故障版本。只有基线通过、故障日志出现实际 TX_COMPLETION 错误记录，才判 KILLED。工具错误或超时不算检出。

<a id="reproduce"></a>

## Run the Check / 运行对照

From the repository root, with PowerShell 7 and a licensed ModelSim/Questa
installation configured as in the [quick start](../README.md#uvm-loopback):

在仓库根目录运行，需要 PowerShell 7 和已配置许可的 ModelSim/Questa，
工具配置见[中文入门](quickstart.md)。

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds tx_early_complete'
```

Success prints `Mutation campaign passed: 1/1`. Check the `tx_early_complete`
entry in `reports/mutation_campaign.json`: `baselinePass` must be true,
`result` must be `KILLED`, and `matchedFailureLines` must contain the detector's
actual error. The command updates working reports, not the published archives.

成功标记为 `Mutation campaign passed: 1/1`。运行会更新工作区报告，不改动归档。
扩展随机模式同样要求成对对照；实际 seed 和命中错误行见该轮
`reports/mutation_campaign.json` 中的 `tx_early_complete` 项。

This case links a status definition to its CDC implementation and independent
timing check. For a different shared-assumption bug, see the
[APB completion-edge case](bug_closure_case.md#english).

这个案例把状态定义、跨域实现和独立时序检查连起来看。
另一个检查器与 DUT 共享错误假设的例子是 [APB 完成沿采样](bug_closure_case.md#chinese)。
