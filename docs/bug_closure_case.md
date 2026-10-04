# APB Completion-Edge Sampling / APB 完成沿采样

[English](#english) · [中文](#chinese) · [Run the checks / 运行对照](#reproduce)

<a id="english"></a>

## Why a Passing Test Missed the Bug

A code review on 2026-09-05 found that PREADY was tied high, but PRDATA and
PSLVERR were updated by nonblocking assignments after the APB completion
edge. The driver and monitor both sampled 2 ns later. They agreed with each
other while missing the same timing violation.

An independent test sampled at the completion edge without using the UVM APB BFM:

| Access | At the completion edge | 2 ns later | Required at the edge |
| --- | --- | --- | --- |
| Read BAUD after reset | 0 | 16 | 16 |
| Read an invalid address | PSLVERR=0 | PSLVERR=1 | PSLVERR=1 |

The earlier 51/51 passing regression therefore did not establish that the
APB timing was correct. Adding more tests with the same late-sampling BFM
would not remove that blind spot.

### The Fix

The [register block](../rtl/apb_uart_regs.sv) now drives read data and errors
combinationally, before the completion edge. Register writes and FIFO
push/pop operations remain clocked. The [APB interface](../tb/interfaces/apb_if.sv)
uses clocking-block `input #1step` sampling for both the
[driver](../tb/uvm/apb_driver.svh) and [monitor](../tb/uvm/apb_monitor.svh).
The error-response assertions check the same transfer, not the next cycle.

The independent [apb_contract_tb.sv](../tb/unit/apb_contract_tb.sv) remains as
a second check outside the UVM driver. It checks reset values, legal and
illegal accesses, loopback reads, and FIFO wraparound, including back-to-back
transfers without an idle PSEL cycle.

### Put the Fault Back

The `apb_late` case enables `UART_MUTATE_APB_LATE_RESPONSE` to delay the
response again. It runs `uart_reg_test` with seed 1071 on both the baseline
and the mutant. The baseline must pass; the mutant must produce an actual
failure record matching `REG_DEFAULT`, `REG_RW`, `SEQ_EXP_ERR`, or the
declared APB assertions. Compilation errors, license failures, and timeouts
do not count as a detected fault. [Run the comparison below](#reproduce).

<a id="chinese"></a>

## 为什么回归通过仍读错数据

2026-09-05 复查代码时发现：PREADY 固定为 1，但 PRDATA 和 PSLVERR 到传输完成沿之后才由非阻塞赋值更新。driver 和 monitor 又都延后 2 ns 读取，所以正常回归一直看不到这段空窗。

独立小测试没有使用原来的 APB BFM，在真正的完成沿直接采样，得到：

| 操作 | 完成沿读到 | 延后 2 ns 读到 | 规格要求 |
| --- | --- | --- | --- |
| 复位后读 BAUD | 0 | 16 | 完成沿应为 16 |
| 非法地址读取 | PSLVERR=0 | PSLVERR=1 | 完成沿应报错 |

这说明问题不只是 DUT 的时序写法，也包括检查器重复了 DUT 的错误假设。历史的 51/51 PASS 不能证明 APB 协议已经正确。

### 修复

寄存器层改成组合读数据和组合错误响应，保证完成沿前有效；配置寄存器写入、TX push 和 RX pop 仍在握手沿更新。driver/monitor 改用 clocking block 的 input #1step 采样，错误响应 SVA 也改为同拍检查。

独立的 [apb_contract_tb.sv](../tb/unit/apb_contract_tb.sv) 保留在仓库，连续访问时 PSEL 不插空闲周期，检查默认值、读写、非法地址、受限访问、loopback 出队和 FIFO 回绕。它不调用 UVM 的 APB driver，因此能对 driver 之外的接口行为作第二次核对。

实现对照：[寄存器响应](../rtl/apb_uart_regs.sv)、[APB clocking block](../tb/interfaces/apb_if.sv)、
[driver](../tb/uvm/apb_driver.svh) 和 [monitor](../tb/uvm/apb_monitor.svh)。

### 把故障放回去

`apb_late` 使用 `UART_MUTATE_APB_LATE_RESPONSE` 让 APB 响应重新晚一拍。
campaign 对同一个 `uart_reg_test`、同一个 seed 1071，先运行正确版本，再运行故障版本：

- 正确版本必须完整结束，无 warning/error/fatal。
- 故障版本必须命中实际错误记录里的 REG_DEFAULT、REG_RW、SEQ_EXP_ERR 或对应 APB SVA。
- 日志只有检测器名字、但错误来自别处，不算检出。
- 许可证、加载失败和超时不算检出。

<a id="reproduce"></a>

## Run the Checks / 运行对照

From the repository root, use PowerShell 7 and licensed ModelSim/Questa.
See the [UVM setup](../README.md#uvm-loopback) or [中文入门](quickstart.md).
The first command runs the independent APB checks; the second runs the
same-test, same-seed baseline/mutant comparison.

在仓库根目录配置好仿真器后，先运行独立 APB 检查，再运行基线与故障版本对照：

```powershell
pwsh -NoProfile -File scripts/run_contract_tests.ps1
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds apb_late'
```

The mutation command succeeds with `Mutation campaign passed: 1/1`.
In `reports/mutation_campaign.json`, check `baselinePass: true`,
`result: "KILLED"` for `apb_late`, and the nonempty `matchedFailureLines`.
The default log names are `logs/mutation_apb_late_baseline_1071.log` and
`logs/mutation_apb_late_1071.log`.

故障对照成功时输出 `Mutation campaign passed: 1/1`。报告中应有基线通过、
`apb_late` 为 `KILLED`，以及实际匹配到的错误行；上面的两个日志分别对应正确版本和故障版本。
完整故障清单见 [mutation_plan.psd1](../config/mutation_plan.psd1)。

The useful lesson is to check the interface with an independent sampling
assumption, then verify that the checker rejects the old defect. A killed
mutation says nothing about faults outside the declared model.

这个案例值得注意的不是测试数量，而是独立采样发现了 DUT 与 BFM 的共同盲区，
再由故障对照确认检查器能拒绝旧缺陷。检出结果只针对声明的故障模型。
