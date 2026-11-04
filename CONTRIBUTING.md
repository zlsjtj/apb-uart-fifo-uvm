# 参与改进 / Contributing

欢迎从一项能独立说明、独立核对的小改动开始。以下三类任务适合这个学习项目：
Start with one small change whose purpose and result can be checked independently:

- **完善一堂练习 / Improve an exercise**：补充清楚的问题、预测、源码定位或答案，复用 [现有练习](examples/learning/README.md) 与真实材料。
- **增加定义清楚的边界测试 / Add a defined boundary test**：说明输入条件、独立期望、失败判据与测试边界；参考 [第一个 UVM 测试](docs/adding_first_test.md)。
- **记录新的工具环境复现 / Record a reproduction on another tool setup**：提供实际命令、版本、运行范围和结果，包括限制或失败；一次成功不等于所有测试都受支持。

## 最小提交要求 / Minimum PR information

先在本地修改，只运行受影响的测试或示例。PR 中说明改了什么、为什么改，以及怎样核对。
纯文档修改检查所改链接即可；每个 PR 不要求完整回归。测试范围应与改动相符，
若确有未验证的行为，请直接写明。
Make the change locally and run the affected tests or example. Explain what changed,
why, and how you checked it. Documentation-only changes need link checks; a full
regression is not required for every PR. State any remaining unverified behavior.

涉及运行结果时，至少提供：
For execution results, include:

- 从仓库根目录运行的准确命令 / Exact command from the repository root.
- 操作系统及实际工具版本 / Operating system and actual tool versions.
- 测试名、seed（适用时）及关键参数 / Test name, seed where applicable, and relevant parameters.
- 通过或失败结果、关键错误与日志位置 / Pass or fail result, relevant errors, and log location.

请勿把旧快照的覆盖率或测试数量当作新改动的结果。涉及故障检出时，应保留同测试、
同 seed 的正确基线，并报告实际 detector；工具失败或超时不算检出。
Keep historical evidence tied to its snapshot. For fault detection, retain a passing
baseline with the same test and seed and report the actual detector; tool failures
and timeouts do not establish detection.

当前工具与证据范围见 [验证范围 / scope](docs/interface_and_scope.md)，
练习入口见 [动手学习 / hands-on learning](examples/learning/README.md)。
