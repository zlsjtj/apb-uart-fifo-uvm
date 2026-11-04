# 动手学习 / Hands-on learning

从一个预测开始，再运行、解释检查器为何通过或报错。所有命令从仓库根目录执行。
Start with a prediction, run the check, then explain the observation. Run commands from the repository root.

| 顺序 / Order | 练习 / Exercise | 工具 / Tools |
| --- | --- | --- |
| 1 | [FIFO 基线与两个反例 / Baseline and two negative controls](fifo.md) | Bash, Icarus, GNU coreutils |
| 2 | [APB 应在何时采样 / Sampling the completion edge](apb.md) | 可先读真实波形；运行需要许可仿真器 / Recorded trace first; licensed simulator to run |
| 3 | [FIFO 空是否发送完成 / Empty versus complete](tx-completion.md) | PowerShell 7, licensed ModelSim/Questa |
| 下一步 / Next | [添加第一个 UVM 测试 / Add your first test](../../docs/adding_first_test.md) | 同上 / Same UVM tools |

这些练习复用现有测试和 compile switch；主干 RTL 保持正确。历史结果的日期和工具范围见
[验证范围 / scope](../../docs/interface_and_scope.md)。
Reuse the existing tests and compile switches; keep the normal RTL correct. Read the linked scope for dated evidence and tool limits.

[首页 / Home](../../README.md) · [复用 APB / Reuse APB](../apb-regblock/README.md)
