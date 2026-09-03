# 正式回归证据说明

## 1. 回归配置

正式回归使用 3 组基准 seed：101、201、301。每一组都执行 16 个用例，脚本会让用例 seed 在基准值上依次递增，因此实际覆盖的 seed 范围分别为 101–116、201–216 和 301–316，共 48 次仿真。

统一时钟配置如下：

```text
pclk_half=5ns  pclk_phase=0ns  uart_half=20ns  uart_phase=0ns
```

执行命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_final_regression.ps1
```

项目级交付验收使用 `scripts/run_acceptance.ps1`。它在正式回归之外，还会执行架构结构检查、两组错相异比时钟测试和四类故障注入，并生成 `reports/acceptance_summary.md`。

## 2. 结果

2026-09-03 在验证架构收口后的正式回归为 48/48 PASS。所有用例的 warning、error、fatal 均为 0。逐项结果见 `reports/final_regression/final_regression_summary.md`，每组 seed 的原始摘要也单独保存在同一目录。

48 个 UCDB 已统一合并。合并结果为：功能覆盖率 100%（65/65 个计划 bin）、断言覆盖率 100%（42/42 条均有有效尝试且无失败）、cover property 100%（14/14 命中）。详细文本报告位于 `reports/final_regression/coverage/`。

## 3. 版本与可复现性

证据包包含以下内容：

- `final_regression_manifest.md`：运行时间、命令、时钟参数、ModelSim/UVM 版本和工作区状态；
- `source_manifest.md`：参与仿真的 RTL、testbench 和关键脚本的 SHA-256；
- `seed_101_summary.md`、`seed_201_summary.md`、`seed_301_summary.md`：三次单组回归的原始摘要；
- `coverage/coverage_manifest.md`：48 个 UCDB 的合并清单；
- `reports/register_model_structural_summary.md`：寄存器统一定义、RAL、adapter 和 predictor 的结构检查结果；
- `reports/cdc_structural_summary.md`：CDC 结构规则检查结果。
- `reports/architecture_structural_summary.md`：监视器解耦、统一配置、文件拆分和 virtual sequence 的结构检查；
- `reports/mutation_matrix.md`：四类故障注入的测试、seed、检出器和量化结果；
- `reports/acceptance_summary.md`：项目级一键验收结果。

本次运行时工作区存在未提交修改。因此清单中的 Git commit 只表示基线，不能单独代表实际仿真版本；应以 `source_manifest.md` 中的 SHA-256 为准。这种记录方式比在脏工作区直接写一个 commit SHA 更可靠。

## 4. 结论与边界

多 seed 回归表明现有 UVM 环境在重复随机化下没有出现不稳定失败，已具备本科设计答辩所需的可复现仿真证据。当前还完成了 CDC 结构审计，详情见 `docs/cdc_analysis.md`；但这不等同于商业 CDC/lint 或形式验证 signoff。

本轮一键验收为 5/5 步通过，两组错相异比时钟子集共 10/10 通过，四类 mutation 为 4/4 KILLED。这里的 mutation score 只覆盖预先选择的四种故障模型，不能外推为穷尽性故障覆盖。
