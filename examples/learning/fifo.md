# 1. FIFO 基线与两个反例 / FIFO baseline and negative controls

**准备 / Prerequisites:** 了解 FIFO 的 push/pop、full/empty 和两个独立时钟；Ubuntu/WSL、Bash、Icarus `iverilog`/`vvp`、GNU `timeout`。无需 UVM。Know FIFO push/pop, flags and independent clocks; no UVM required.

## 先预测 / Predict first

1. 深度为 2 的 FIFO 写满后，如果 full 恒为 0，单看“仿真结束”能证明正确吗？
2. 如果只把读数据翻转一位，full/empty 检查会发现吗？需要什么独立期望？

If full is stuck low, does reaching the end prove correctness? If only read data changes, which independent observation detects it?

## 运行与观察 / Run and inspect

```bash
bash scripts/run_fifo_smoke.sh
```

脚本打印 `Logs: ...`，每次输出到新的 `work_fifo_smoke/run.*`。看该目录的
`summary.txt`、`w1_3_5.log`、`full_stuck_low.log` 和 `corrupt_read.log`。
Inspect these files in the printed directory. The intended result is eight passing
baselines and two detected faults, ending with:

```text
FIFO smoke: 8/8 baselines passed; 2/2 injected faults detected.
```

跟踪 [脚本](../../scripts/run_fifo_smoke.sh) 的 `run_case` 和
[reference queue](../../tb/unit/async_fifo_random_tb.sv) 的入队、出队与比较。
第一条基线和两个反例都使用 width=1、WR_HALF=3、RD_HALF=5、seed=1401。
Full 反例用 `UART_MUTATE_FIFO_FULL_STUCK_LOW`；读数据反例用测试台参数
`INJECT_READ_ERROR=1`，故障位于观测通路。它们不是两次“正常测试失败”。
Trace the queue updates and comparisons: one negative mutates FIFO full logic;
the other corrupts observed read data through a testbench parameter.

## 小修改 / Small change

只在工作分支将 `INJECT_READ_ERROR` 对读数据的 XOR mask 从 `8'h01` 改为
`8'h80`，重跑脚本，预测哪个 detector 应保持不变，再恢复修改。不要关闭比较。
On a working branch change only the read-error XOR mask to `8'h80`, rerun, explain
which detector remains the same, then restore the change. Keep the comparison active.

<details>
<summary>提示与答案 / Hint and answer</summary>

Reference queue 根据实际接受的写事务保存原始值，不从 DUT 读数据构建期望。
full 恒低允许过多写入，触发 `FIFO_REFERENCE_OVERFLOW`；读值翻转（无论 bit 0
还是 bit 7）触发 `FIFO_REFERENCE_ORDER`。脚本要求负例退出码为 1、匹配指定
FATAL、且无 `FIFO_RANDOM_PASS`；编译失败或 timeout 不计为检出。
The queue supplies an independent data oracle. Overflow and ordering are different
checks. The script validates the expected fatal and exit status, rather than accepting
any failed process as evidence.

</details>

这里只证明这些配置下的队列检查与两个反例；不证明全部 CDC 行为，也不增加历史
13 项 mutation campaign 的数量。Icarus 路径不运行四条不支持的 inline SVA。
This checks the listed configurations and controls; it does not establish complete CDC
correctness. See [检查模式 / checking patterns](../../docs/checking_patterns.md).
