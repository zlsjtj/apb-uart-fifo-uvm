# 本轮验收与论文结果表

运行：20260913_134519_8d9500ab。以下数字只对应这一轮，不累计历史测试。
源码 SHA-256：801771a6c2ea8619f01c11ef8486d560b72c1799655f4894328f3d0c6915ff85

随机模式：expanded，campaign seed：20000，正式回归基准 seed：4701, 4801, 4901。

| 检查 | 本轮结果 | 证据 |
| --- | --- | --- |
| 完整验收 | 12/12 PASS | [验收摘要](acceptance_summary.json) |
| 正式 UVM 回归 | 60/60 | [回归](reports/final_regression/final_regression_summary.json) |
| FIFO 深度参数子集 | 24/24 | [参数矩阵](reports/parameter_regression/summary.json) |
| 无探针模式 | 4/4 | 同上 |
| 快 UART、慢 APB | 2/2 | 同上 |
| 错相压力 | 16/16 | reports/stress |
| 独立 FIFO 随机测试 | 8/8 | [FIFO 单元](reports/fifo_unit_tests.json) |
| 故障注入 | 13/13 KILLED | [同测试、同种子基线](reports/mutation_campaign.json) |
| Covergroup Bins | 69/69 | [覆盖率门禁](reports/final_regression/coverage/functional_assertion_gate.json) |
| Cover Directives | 16/16 | [覆盖率门禁](reports/final_regression/coverage/functional_assertion_gate.json) |
| Assertions | 66/66 | [覆盖率门禁](reports/final_regression/coverage/functional_assertion_gate.json) |
| RTL 门禁 | 19/19 | [RTL 门禁](reports/final_regression/coverage/rtl_coverage_gate.json) |
| CDC 路径分类 | 60/60，Critical 0，Warning 47 | [CDC 审核](reports/synthesis/cdc_review.json) |

OOC 器件：xc7a35tcpg236-1；Slice LUT：280；Slice Registers：305；LUT as Memory：16；总体 setup WNS：1.968 ns。

这些结果说明计划范围内的仿真、覆盖率门禁和综合检查通过，不是无缺陷证明，也不是布局布线、板级频率或真实串口运行证据。
交付清单使用相对路径，可在搬移后校验。原始日志和报告中的本机绝对路径作为运行出处保留，不作为交付包导航入口。
