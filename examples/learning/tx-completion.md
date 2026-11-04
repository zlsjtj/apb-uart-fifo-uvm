# 3. FIFO 空与发送完成 / Empty FIFO versus completed TX

**准备 / Prerequisites:** 理解 8N1 的起始位、八个数据位和完整停止位，以及跨域同步延迟。
运行需要 PowerShell 7 和按[入门](../../docs/quickstart.md)配置的许可 ModelSim/Questa。
Know 8N1 framing and CDC synchronization latency. The [loopback sample](../loopback/README.md)
helps visualize serial bits; it is not the timing evidence for this mutation.

## 先预测 / Predict first

最后一个字节出 FIFO 时 `TX_EMPTY=1`，串行线是否已发完？停止位刚开始时，
`TX_BUSY` 能否清零？跨域同步导致 busy 稍晚清零与提前清零哪个会截断数据？
Can FIFO empty imply delivery? Can busy clear at the start of the stop bit?
Compare a delayed completion indication with an early one.

## 运行与观察 / Run and inspect

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds tx_early_complete'
```

此 case 用 `uart_tx_completion_test`、seed `1318`，先基线，再用
`UART_MUTATE_TX_EARLY_COMPLETE`。预期 `Mutation campaign passed: 1/1`。
在 `reports/mutation_campaign.json` 中核对 `baselinePass=true`、`result=KILLED`
及含 `TX_COMPLETION` 实际错误的 `matchedFailureLines`，并按报告路径打开日志。
Check both outcomes and the actual detector lines. A timeout or tool failure is not a kill.

从 [TX 案例](../../docs/tx_completion_case.md) 到
[completion sequence](../../tb/uvm/sequences/uart_completion_sequences.svh)，
跟踪公开 TX 引脚的帧起点、停止位窗口内的 STATUS 读取与之后的回环检查；
再看 [completion CDC](../../rtl/tx_completion_cdc.sv)。
The test computes timing independently from the public TX pin and declared baud/clock,
then checks busy during the stop bit and eventual loopback data. Identify where the
RTL advances the completed-frame count and where the mutation moves that event.

## 小修改 / Small change

在工作分支将 completion sequence 的测试 payload 换成另一字节（保留同一变量
对发送与期望的连接），先预测 busy 的停止位要求会不会改变，然后重跑该 case 并恢复。
定位具体变量和写入点属于练习；不要改时间公式或禁用 detector。
Change the payload, keeping send and expected data connected, rerun the paired case,
and restore it. Predict whether the stop-bit completion requirement depends on payload.

<details>
<summary>提示与答案 / Hint and answer</summary>

8N1 的帧长不随 payload 改变；FIFO 出队仅说明字节已交给串行发送器，完整停止位结束
才可推进完成计数。同步延迟可以让 busy 保守地晚清零，但不能使它早清零。
基线应通过、提前完成版本仍应出现 `TX_COMPLETION`。如果没命中，检查实际刺激与
停止位采样窗口，不能把任意失败当检出。disable/reset 是中止/丢弃，不能用它们清 busy
来证明成功送达。
Payload does not change 8N1 frame length. The timing oracle must remain independent
of the DUT completion event. Reset or disable can discard data and are not delivery checks.

</details>

历史成功说明见案例；本练习未声明新增仿真结果。下一步：[添加第一个测试](../../docs/adding_first_test.md)。
