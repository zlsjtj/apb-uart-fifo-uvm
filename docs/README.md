# Documentation / 文档索引

[English](#english) · [中文](#chinese)

<a id="english"></a>

## Start Here

Start with [one runnable example](../README.md#choose-a-run), then
[follow one byte through the UVM environment](../README.md#follow-one-byte-through-uvm).
No commercial simulator is needed to inspect the [recorded loopback](../examples/loopback/README.md).

| What to read | Entry |
| --- | --- |
| Adapt a predictor, an independent timing check, or a baseline-controlled fault test | [Three checking patterns](checking_patterns.md) |
| Hardware data path, UVM connections and configuration CDC | [Architecture](architecture_figures.md) |
| Interface contract, tested tools and result interpretation | [Verification scope](interface_and_scope.md) |
| A passing regression that sampled APB too late | [APB debugging case](bug_closure_case.md#english) |
| Fixed response versus an injected timing fault | [VCD comparison and short replay](../examples/apb-timing/README.md) |
| Why an empty TX FIFO is not a completed frame | [TX completion case](tx_completion_case.md#english) |
| Default tests and stress profiles | [Executable test plan](../config/verification_plan.psd1) |
| Injected faults and their detectors | [Mutation plan](../config/mutation_plan.psd1) |
| Saved results and source identity | [2026-09-13 manifest](../reports/published/20260913_134519_8d9500ab/acceptance_summary.json) |

The model is fixed 8N1, not a production UART IP. The CI badge covers the free
FIFO test only. Saved UVM results belong to their dated source snapshots, not
every later commit. Detailed acceptance instructions and historical notes below
are in Chinese; the [English README](../README.md) includes simulator setup and
output paths for the introductory run.

<a id="chinese"></a>

## 中文导航

第一次阅读从 [跑通一个测试](quickstart.md) 开始。想了解测试怎样发现问题，
先看 [APB 完成沿采样](bug_closure_case.md#chinese) 和 [TX 发送完成](tx_completion_case.md#chinese)。

## 设计与测试

| 想了解什么 | 入口 |
| --- | --- |
| 数据通路、UVM 连接和配置跨域 | [架构图](architecture_figures.md) |
| 当前模块职责 | [当前架构](current_architecture_and_optimization.md) |
| 简化 UART 的功能与边界 | [需求与范围](requirements_and_scope.md) |
| 寄存器模型和预测方式 | [RAL](register_model.md) |
| 跨时钟、复位及检查限制 | [CDC 分析](cdc_analysis.md) |
| 默认测试和压力配置 | [verification_plan.psd1](../config/verification_plan.psd1) |
| 故障注入对象与检测器 | [mutation_plan.psd1](../config/mutation_plan.psd1) |
| RTL 覆盖率阈值与豁免 | [rtl_coverage_policy.psd1](../config/rtl_coverage_policy.psd1) |

## 运行与证据

[复现与交付](reproduction_and_delivery.md) 说明工具配置、完整验收与结果导出。
[最新已保存结果入口](../reports/published/latest.json) 指向某一轮固定快照的摘要。
GitHub 上能查看轻量 JSON 和结果表；完整日志、UCDB、HTML 和交付包保存在本地。
另有小型 [回环样本](../examples/loopback/README.md)，包含波形预览、原始 VCD、
日志摘录、校验值和 PNG 生成脚本。
新增的 [APB 时序对照](../examples/apb-timing/README.md) 提供固定版本与故障注入版本的
真实 VCD、报告摘录和短回放，可以直接在浏览器中查看。

| 任务 | 在仓库根目录执行 |
| --- | --- |
| 免费 FIFO 自检，Ubuntu/WSL | `bash scripts/run_fifo_smoke.sh` |
| 完整验收 | `pwsh -NoProfile -File scripts/run_acceptance.ps1` |
| 独立 APB 协议测试 | `pwsh -NoProfile -File scripts/run_contract_tests.ps1` |
| 独立 FIFO 随机测试 | `pwsh -NoProfile -File scripts/run_fifo_unit_tests.ps1` |
| FIFO 深度与无探针子集 | `pwsh -NoProfile -File scripts/run_parameter_regression.ps1` |
| 13 项故障注入对照 | `pwsh -NoProfile -File scripts/run_mutation_campaign.ps1` |
| 三个基准 seed 的回归 | `pwsh -NoProfile -File scripts/run_final_regression.ps1` |
| RTL 静态检查 | `pwsh -NoProfile -File scripts/run_static_checks.ps1` |
| OOC 综合与 CDC 报告 | `pwsh -NoProfile -File scripts/run_vivado_synth.ps1` |

每次单独运行会更新相应的工作区报告。讨论某轮结果时，应同时给出 run ID、
源码身份、工具版本和 seed。[2026-09-13 结果表](../reports/published/20260913_134519_8d9500ab/paper_results.md)
是一个固定入口；其中的数字不代表之后每个提交都重新通过完整验收。

## 历史记录

以下文档保留了开发时的阶段判断、失败和修复。文件名中的 P0/P1/P2 是当时的
任务编号；从这些文档读取测试数或覆盖率时，请保留其日期和运行范围。

- [早期调试笔记](debug_notes.md)、[覆盖率笔记](coverage_summary.md)、[覆盖率整理](coverage_closure.md)。
- [需求追溯表](traceability_matrix.md)、[早期多 seed 回归](final_regression_evidence.md)。
- [P0/P1 计划](p0_p1_finish_plan.md)、[结果](p0_p1_finish_result.md)、[9 月 5 日协议修复](p0_p2_contract_closure.md)。
- [验证环境拆分](p2_verification_architecture.md)、[架构调整](architecture_optimization.md)、[阶段核对](verification_architecture_closure.md)、[P0-P4 记录](p0_p4_optimization_closure.md)。
- [运行与交付改进计划](engineering_delivery_plan.md)、[两轮验收结果](engineering_delivery_result.md)。

实际支持范围以当前源码、可执行测试计划和所引用的那轮结果为准。
