# 添加第一个 UVM 测试 / Add your first UVM test

本例已提供可注册、可单独运行的 `uart_learning_baud_test`：检查 BAUD 写 0 归一为 1，
再检查 1、7、16 的读回和合法访问的 PSLVERR。它练习“明确期望 + 配置握手 + 失败报告”，
不需要白盒 probe，也不产生串行流量。代码已接入 include，并在
[Verilator 小范围试跑](verilator_feasibility.md)中运行通过；已有 20 项默认回归与历史
覆盖率数字保持原来的运行范围。
The optional test is included and factory registered. Its observed result and exact
Verilator/UVM configuration are recorded in the linked pilot report.

## 准备与源码 / Prerequisites and source

需要基本 SystemVerilog class/task、UVM factory/sequence/objection 知识，以及
PowerShell 7、许可 ModelSim/Questa；环境配置见[快速入门](quickstart.md)。
No Icarus UVM support is assumed. Read these files in order:

| 文件 / File | 作用 / Role |
| --- | --- |
| [uart_base_reg_sequences.svh](../tb/uvm/sequences/uart_base_reg_sequences.svh) | APB transaction helpers; bounded `wait_tx_idle` and `wait_config_ready` |
| [uart_learning_sequences.svh](../tb/uvm/sequences/uart_learning_sequences.svh) | `check_baud(requested, expected)` checks write error, waits, checks read error and value |
| [uart_learning_tests.svh](../tb/uvm/tests/uart_learning_tests.svh) | Factory registration; objection around sequence on `env.apb.seqr` |
| [uart_sequences.svh](../tb/uvm/uart_sequences.svh), [uart_tests.svh](../tb/uvm/uart_tests.svh) | Include fragments after their base classes; already included by `uart_pkg.sv` |
| [register constants](../rtl/apb_uart_reg_pkg.sv) | Addresses and contract values |

先预测 `check_baud(0, 1)` 为什么不能写成“读回什么，就把什么当作 expected”。
Before running, explain why copying readback into expected would remove the check.

## 单独运行 / Run it alone

在仓库根目录执行，与普通 UVM 测试共用编译流程：
Use the existing compile/run flow from the repository root:

```powershell
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_learning_baud_test -Seed 1701
```

检查该命令打印的日志/报告位置和 test/seed，不要只搜一个成功字符串。
确认 test 被 factory 找到、仿真正常结束，UVM summary 中 ERROR/FATAL 为 0，
且 runner 对该项判通过。`LEARN_BAUD_WRITE` 表示合法写访问返回错误；
`LEARN_BAUD_READ` 给出 requested、expected、actual、PSLVERR。
超时、factory 找不到类或编译失败都不是验证通过。
Inspect the runner's paths and result for this test and seed. Require normal completion,
zero UVM errors/fatals, and a passing runner result. A missing class or tool error is not a pass.

小修改：新增 `check_baud(31, 31)`，先解释期望来源，再单独运行。随后在自己的工作分支
临时把 `check_baud(0, 1)` 的期望改成 2：应出现 `LEARN_BAUD_READ`，证明比较路径有效，
最后恢复正确期望。这是检查器自检，不是新 RTL mutation。
Add one legal value. Then temporarily make the zero-write expectation wrong, verify
the detector fires, and restore it. This checks the assertion path without changing RTL.

<details>
<summary>为什么采用这个结构 / Why this structure</summary>

先 `wait_tx_idle()` 遵守重配置约束；raw `apb_write_status` 保留写返回错误供检查，
`wait_config_ready()` 等配置握手；`apb_read_status` 同时检查数据和访问状态。
期望是显式契约值，不依赖 DUT 读回，也不把打印成功消息当判据。
The base helpers provide bounded polling and APB transport. The test owns its oracle.
The sequence checks register semantics; it does not establish serial baud accuracy,
CDC signoff or frame completion. Those need their dedicated existing tests.

</details>

## 把自己的测试纳入计划 / Add your test to the plan

目前 `config/verification_plan.psd1` 的 `RegressionTests` 仍为原来 20 项。
若你希望自己的测试成为默认回归，在该数组加入唯一类名，例如：

```powershell
RegressionTests = @(
  # existing entries ...
  'uart_learning_baud_test'
)
```

这是示意片段，不要用它覆盖完整文件。选择与新行为对应的 seed/运行范围，执行相应回归，
保留新报告，再更新你自己的测试数量和结果声明。不要直接把旧的 60/60 或覆盖率数字
解释为包含新测试。只有确实适用于深度变化或无探针运行时，才考虑加入 `ParameterTests`
或 `NoProbeTests`；不要为了出现更多列表而盲目添加。
This snippet illustrates one entry, not a replacement file. Run the changed plan before
claiming new totals; historical evidence remains tied to its original snapshot.

[三项练习 / Exercises](../examples/learning/README.md) · [检查模式 / Patterns](checking_patterns.md)
