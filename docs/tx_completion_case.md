# 发送结束为什么不能只看 FIFO 空

## 问题

TX FIFO 的最后一个字节被取走时，串行发送才刚开始。如果软件把 TX_EMPTY 当作发送结束，随后立即修改 BAUD 或关闭 UART，就可能截断还在发送的字节。

即使另加 busy 位，也要说明何时清零：输出停止位的上升沿只是停止位开始，不是整帧结束。接收端还需要一个完整位周期。

## 当前实现

APB 域对成功接受的 TXDATA 写计数，UART 域在完整停止位结束后对完成数计数。完成计数寄存为 Gray 码，经两级同步返回，与 APB 接收计数比较生成 TX_BUSY。计数宽度为 FIFO 地址宽度加 2，给最小 FIFO 与完成流水级留出余量。

刚写入、尚未传到 UART 域的数据已经计入 busy；停止位尚未结束的数据也仍在 busy 内。正常配置流程必须等待 TX_BUSY 和 CFG_BUSY 都为 0，再写配置，最后等 CFG_BUSY 清零。外部 RX 空闲仍由通信协议保证。

disable 是显式中止，reset 会丢弃在途和排队数据。因此这两种操作后的 busy 清零不代表数据成功送达。这个边界不能在论文里省略。

## 怎样验证检查器确实能发现提前结束

uart_tx_completion_test 从公开 TX 引脚定位帧起点，根据声明的时钟与波特率计算停止位窗口，在停止位中间读 STATUS，要求 TX_BUSY 仍为 1；结束后轮询清零，并检查回环读回数据。

UART_MUTATE_TX_EARLY_COMPLETE 故意在停止位开始时报告完成。campaign 先运行同测试、同种子的正确基线，再运行故障版本。只有基线通过、故障日志出现实际 TX_COMPLETION 错误记录，才判 KILLED。工具错误或超时不算检出。

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds tx_early_complete'
```

扩展随机模式也保留这个成对条件。本轮实际使用的种子和命中错误行，见所选交付包 reports/mutation_campaign.json 中 id 为 tx_early_complete 的记录；这里不手抄运行数字。

这个案例展示的是状态定义、跨域实现和独立检查之间的对应关系，不是增加一个寄存器位就完成验证。它可与 bug_closure_case.md 的 APB 完成沿案例配合用于答辩。
