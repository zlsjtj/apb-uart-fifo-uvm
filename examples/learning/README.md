# 动手学习 / Hands-on learning

从一个预测开始，再运行、解释检查器为何通过或报错。所有命令从仓库根目录执行。
Start with a prediction, run the check, then explain the observation. Run commands from the repository root.

| 顺序 / Order | 练习 / Exercise | 工具 / Tools |
| --- | --- | --- |
| 1 | [FIFO 基线与两个反例 / Baseline and two negative controls](fifo.md) | Bash, Icarus, GNU coreutils |
| 2 | [APB 应在何时采样 / Sampling the completion edge](apb.md) | 可先读真实波形；运行需要许可仿真器 / Recorded trace first; licensed simulator to run |
| 3 | [FIFO 空是否发送完成 / Empty versus complete](tx-completion.md) | PowerShell 7, licensed ModelSim/Questa |

这些练习只整理 main 已有的测试、故障开关和案例，不增加或修改 RTL、测试类、运行脚本或覆盖率要求。
The exercises use checks already present on main; no implementation or acceptance policy changes are included.

<a id="tools-and-scope"></a>

## 工具与范围 / Tools and scope

- FIFO 路线使用 Ubuntu/WSL、Bash、GNU coreutils 和 Icarus 12.0，无需 UVM。
- APB 和 TX 故障对照的历史验证环境是 ModelSim SE-64 10.4、UVM 1.1d 和 PowerShell 7。
  命令复用 main 的入口；不要将其理解为所有 Questa 版本都已通过兼容性验收。
- [v0.1.0](https://github.com/zlsjtj/apb-uart-fifo-uvm/releases/tag/v0.1.0) 的证据包含
  8/8 FIFO 基线、两个负例和 13 项配对故障检查。结果属于该版本和工具环境；
  本次文档整理没有新增仿真结果，也没有替用户实际尝试“小修改”。

The recorded UVM setup is ModelSim 10.4, not a general compatibility guarantee.
Keep each baseline, detector and tool failure distinct. See [verification scope](../../docs/interface_and_scope.md).

## 保留依赖的后续内容 / Separate follow-ups

[PR #1](https://github.com/zlsjtj/apb-uart-fifo-uvm/pull/1) 仍为未合并的 Draft，完整覆盖率验收未通过。
它提供的 [BAUD 入门测试](https://github.com/zlsjtj/apb-uart-fifo-uvm/blob/b2fe572dc187de9a789975f47475d0bfda5a03c8/docs/adding_first_test.md)
和 [APB agent 复用示例](https://github.com/zlsjtj/apb-uart-fifo-uvm/blob/b2fe572dc187de9a789975f47475d0bfda5a03c8/examples/apb-regblock/README.md)
依赖该 PR 新增的测试、公共包或脚本，**不包含在本分支中，不能直接在 main 执行其中的新命令**。
Those optional additions depend on the unmerged PR; they are not prerequisites for these three exercises.

[首页 / Home](../../README.md) · [现有检查模式 / Checking patterns](../../docs/checking_patterns.md)
