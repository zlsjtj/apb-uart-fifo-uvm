# 正式回归证据说明

## 1. 回归配置

正式回归使用 3 组基准 seed：101、201、301。每一组都执行 17 个用例，脚本会让用例 seed 在基准值上依次递增，因此实际覆盖的 seed 范围分别为 101–117、201–217 和 301–317，共 51 次仿真。

统一时钟配置如下：

```text
pclk_half=5ns  pclk_phase=0ns  uart_half=20ns  uart_phase=0ns
```

执行命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_final_regression.ps1
```

项目级交付验收使用 `scripts/run_acceptance.ps1`。它在正式回归之外，还会执行 RTL lint、CDC/RDC 结构检查、通用器件综合、架构检查、两组错相异比时钟测试和声明式故障注入，并生成 Markdown/JSON 摘要。

## 2. 结果

2026-09-04 的正式回归为 51/51 PASS。所有用例的 warning、error、fatal 均为 0。逐项结果见 `reports/final_regression/final_regression_summary.md`，每组 seed 的原始摘要也单独保存在同一目录。

51 个 UCDB 已统一合并。合并结果为：功能覆盖率 100%（65/65 个计划 bin）、断言覆盖率 100%（51/51 条均有有效尝试且无失败）、cover property 100%（15/15 命中），RTL-only 门禁 17/17。详细文本、JSON 和 HTML 报告位于 `reports/final_regression/coverage/`。

## 3. 版本与可复现性

证据包包含以下内容：

- `final_regression_manifest.md`：运行时间、命令、时钟参数、ModelSim/UVM 版本和工作区状态；
- `source_manifest.md`：参与仿真的 RTL、testbench 和关键脚本的 SHA-256；
- `seed_101_summary.md`、`seed_201_summary.md`、`seed_301_summary.md`：三次单组回归的原始摘要；
- `coverage/coverage_manifest.md`：51 个 UCDB 的合并清单；
- `reports/register_model_structural_summary.md`：寄存器统一定义、RAL、adapter 和 predictor 的结构检查结果；
- `reports/cdc_structural_summary.md`：CDC 结构规则检查结果。
- `reports/architecture_structural_summary.md`：监视器解耦、统一配置、文件拆分和 virtual sequence 的结构检查；
- `reports/mutation_campaign.md`：十一类故障注入的测试、seed、检出器和量化结果；
- `reports/synthesis/qor.json`：通用 Artix-7 综合的资源与综合后时序数据；
- `reports/acceptance_summary.md`：项目级一键验收结果。

本次运行时工作区存在未提交修改。因此清单中的 Git commit 只表示基线，不能单独代表实际仿真版本；应以 `source_manifest.md` 中的 SHA-256 为准。这种记录方式比在脏工作区直接写一个 commit SHA 更可靠。

## 4. 结论与边界

多 seed 回归表明现有 UVM 环境在重复随机化下没有出现不稳定失败，已具备本科设计答辩所需的可复现仿真证据。当前还完成了零告警 RTL lint、CDC/RDC 结构审计和通用器件综合；但这不等同于商业 CDC signoff、布局布线时序或上板结果。

本轮一键验收为 7/7 步通过，两组错相异比时钟子集共 12/12 通过，十一类 mutation 为 11/11 KILLED。这里的 mutation score 只覆盖清单中的代表性故障模型，不能外推为穷尽性故障覆盖。
