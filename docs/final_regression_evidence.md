# 正式回归证据说明

## 1. 回归配置

正式回归使用 3 组基准 seed：101、201、301。每一组都执行 13 个既有用例，脚本会让用例 seed 在基准值上依次递增，因此实际覆盖的 seed 范围分别为 101–113、201–213 和 301–313，共 39 次仿真。

统一时钟配置如下：

```text
pclk_half=5ns  pclk_phase=0ns  uart_half=20ns  uart_phase=0ns
```

执行命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_final_regression.ps1
```

## 2. 结果

2026-09-03 在 P0 复位优化后的正式回归为 39/39 PASS。所有用例的 warning、error、fatal 均为 0。逐项结果见 `reports/final_regression/final_regression_summary.md`，每组 seed 的原始摘要也单独保存在同一目录。

39 个 UCDB 已统一合并。合并结果为：功能覆盖率 100%（65/65 个计划 bin）、断言覆盖率 100%（40/40 条均有有效尝试且无失败）、cover property 100%（13/13 命中）。详细文本报告位于 `reports/final_regression/coverage/`。

## 3. 版本与可复现性

证据包包含以下内容：

- `final_regression_manifest.md`：运行时间、命令、时钟参数、ModelSim/UVM 版本和工作区状态；
- `source_manifest.md`：参与仿真的 RTL、testbench 和关键脚本的 SHA-256；
- `seed_101_summary.md`、`seed_201_summary.md`、`seed_301_summary.md`：三次单组回归的原始摘要；
- `coverage/coverage_manifest.md`：39 个 UCDB 的合并清单。
- `reports/cdc_structural_summary.md`：CDC 结构规则检查结果。

本次运行时工作区存在未提交修改。因此清单中的 Git commit 只表示基线，不能单独代表实际仿真版本；应以 `source_manifest.md` 中的 SHA-256 为准。这种记录方式比在脏工作区直接写一个 commit SHA 更可靠。

## 4. 结论与边界

多 seed 回归表明现有 UVM 环境在重复随机化下没有出现不稳定失败，已具备本科设计答辩所需的可复现仿真证据。当前还完成了 CDC 结构审计，详情见 `docs/cdc_analysis.md`；但这不等同于商业 CDC/lint 或形式验证 signoff。
