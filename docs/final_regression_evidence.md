# 正式验收与证据复现

## 从哪里看结果

先看 reports/acceptance_summary.json 的 result 和 runId。只有 PASS 才表示整轮完成；RUNNING 不能当作通过，FAIL 的错误和已完成步骤仍会保留。不要把目录中较早的 PASS 摘要拿来代替最近一次失败。

每轮实际工作区是 reports/acceptance_runs/<runId>/workspace。这个目录包含当轮源码、脚本、声明式配置、日志、UCDB 和报告，不复用上一次的仿真库或覆盖率文件。

## 验收内容

1. 证据门禁反向测试：空日志、无关错误、超时、缺 UCDB、覆盖率缺项、源码变化、过期 PASS 和未知 CDC 路径必须被拒绝。
2. RTL lint 和结构审计。
3. 独立 APB 完成沿检查与 FIFO 参数测试。地址宽度 1..16 全部 elaboration，1、2、4、6 另做功能和多次回绕，不能把 elaboration-only 写成完整功能验证。
4. OOC 综合、接口约束、资源报告、setup 时序和 CDC 路径分类。
5. 三组基准 seed 的完整 UVM 回归、UCDB 合并及覆盖率门禁。
6. verification_plan 中各组错相异比时钟压力用例，分别保存摘要。
7. mutation 每个用例先跑同测试同 seed 的无故障基线，再跑故障版，记录对应错误记录。

## 如何运行

```powershell
pwsh -NoProfile -File scripts/run_acceptance.ps1
```

测试和参数由 config/verification_plan.psd1 维护。更改脚本、RTL、测试、约束或配置后都要重新运行；验收开始和结束会比较 SHA-256，不接受边运行边修改源码的结果。

只想做调试时可以运行 run_questa.ps1 的用例子集，但这不会取代完整验收。UCDB 缺失时 merge_coverage.ps1 必须失败；功能 bin、cover directive 和 assertion 活跃项也必须达到门禁，不能只生成报告不检查。

## 关键文件

以下路径均相对于对应轮次的 workspace：

| 文件 | 用途 |
| --- | --- |
| reports/final_regression/final_regression_summary.md | 各测试实际 seed 和结果 |
| reports/final_regression/source_manifest.json | 仿真输入的完整文件哈希 |
| reports/final_regression/coverage/functional_assertion_gate.json | 功能和断言覆盖门禁 |
| reports/final_regression/coverage/rtl_coverage_gate.json | RTL 阈值和 waiver |
| reports/stress/<profile>/ | 每组错相压力摘要 |
| reports/mutation_campaign.json | 基线、故障结果及命中的错误记录 |
| reports/synthesis/qor.json | OOC 资源和时序口径 |
| reports/synthesis/cdc_review.json | 逐条 CDC 端点分类 |
| reports/contract_tests.json | 参数化独立 APB 测试结果 |
| reports/evidence_gate_selftests.json | 门禁反向测试结果 |

## 版本与结论边界

baselineCommit 只说明本轮从哪个提交开始；实际未提交代码由 source.sha256 标识。用户本轮要求不 commit、不 push，因此不能用“提交完成”来描述交付状态。

旧的 2026-09-04 51/51 回归属于历史版本，APB 晚响应问题当时未被检出。新的协议检查、基线对照和反向门禁是对这条证据边界的修正，不是简单增加用例数量。

综合不等于布局布线，setup WNS 不等于板级最高频率，内部 CDC 路径分类不等于真实异步 RX 或商业 signoff。
