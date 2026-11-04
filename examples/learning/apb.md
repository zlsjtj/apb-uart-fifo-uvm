# 2. APB 完成沿 / APB completion-edge sampling

**准备 / Prerequisites:** 理解 APB setup/access、`PSEL && PENABLE && PREADY` 完成条件和时钟采样。
先打开 [真实对照与回放 / recorded comparison](../apb-timing/README.md)，不需要仿真器。
运行使用 PowerShell 7 和按[入门](../../docs/quickstart.md)配置的许可仿真器；
已记录工具及版本边界见[练习入口](README.md#tools-and-scope)。
Know the APB phases and completion condition. Recorded traces can be inspected without a simulator.

## 先预测 / Predict first

若零等待 APB 在完成沿之后才更新 PRDATA，而 driver 和 monitor 都延迟采样，
测试为何可能通过？把两者一起改成晚采样是在修复哪一方？
If PRDATA arrives after completion and both observers read late, why might a test
pass? Which contract has actually been checked?

## 运行与观察 / Run and inspect

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds apb_late'
```

该 case 固定用 `uart_reg_test`、seed `1071`，先正确基线，再带
`UART_MUTATE_APB_LATE_RESPONSE` 的故障版本。看
`logs/mutation_apb_late_baseline_1071.log`、`logs/mutation_apb_late_1071.log` 和
`reports/mutation_campaign.json` 的对应项：`baselinePass=true`、`result=KILLED`、
非空 `matchedFailureLines`；总输出应为 `Mutation campaign passed: 1/1`。
The paired run holds test and seed constant. A killed mutant requires a passing
baseline and actual matching error lines; inspect the records, not only the final message.

读 [案例 / case](../../docs/bug_closure_case.md)，再看
[driver](../../tb/uvm/apb_driver.svh)、[monitor](../../tb/uvm/apb_monitor.svh)、
[寄存器测试序列](../../tb/uvm/sequences/uart_base_reg_sequences.svh) 和
[APB RTL](../../rtl/apb_uart_regs.sv)。真实回放里 BAUD reset 应为 16，晚响应采到 0，
产生 `REG_DEFAULT`。各轮实际报错以自己的日志为准。
Read the completion-edge sampling code and the explicit reset-value oracle.
The recorded comparison shows 16 versus 0; your run's matched lines are its evidence.

## 小修改 / Small change

在工作分支把 `uart_reg_seq` 的 BAUD reset 读取前 idle cycles 从 1 改为 3，
再跑同一 case。先预测：增加两笔传输之间的空闲能否让完成沿之后的数据变合法？
结束后恢复修改。Change only the idle-cycle argument before the BAUD reset read,
rerun the same case, and restore it. Predict whether inter-transfer idle cycles can
repair a response that misses its own completion edge.

<details>
<summary>提示与答案 / Hint and answer</summary>

不能。空闲周期改变传输开始时间，不改变这笔传输的采样契约。正确基线应继续通过，
故障版本仍应被有效 detector 检出。driver、monitor 和 DUT 共享相同错误假设时，
“彼此一致”不等于遵循接口。完成沿 SVA 与固定期望提供独立约束。
No: idle cycles shift the transaction, not its response deadline. Agreement between
DUT and observers can hide a shared timing mistake. Independent edge checks and
explicit expected values constrain that mistake.

</details>

使用 compile switch 重现缺陷，不把旧错误复制成另一份 RTL。
对应独立检查的复用方式见 [checking patterns](../../docs/checking_patterns.md)。
