# 覆盖率闭环说明

## 1. 数据来源

功能闭环的首轮结果来自 2026-07-13 的 13/13 PASS 回归。验证架构收口后，2026-09-03 使用 `scripts/run_final_regression.ps1` 完成 3 组 seed、48/48 PASS 的正式回归，并合并 48 个 UCDB；正式证据见 `docs/final_regression_evidence.md` 和 `reports/final_regression/`。`scripts/merge_coverage.ps1` 只选择摘要表中对应测试和 seed 的 UCDB，不合并目录中其他调试运行或旧 seed。

生成内容：

- `reports/final_regression/coverage/regression_merged.ucdb`
- `reports/final_regression/coverage/coverage_totals.txt`
- `reports/final_regression/coverage/functional_coverage.txt`
- `reports/final_regression/coverage/code_coverage.txt`
- `reports/final_regression/coverage/assertion_coverage.txt`
- `reports/final_regression/coverage/dut_bydu_coverage.txt`
- `reports/final_regression/coverage/rtl_coverage_gate.md`
- `reports/final_regression/coverage/rtl_coverage_gate.json`
- `reports/final_regression/coverage/html/index.html`

## 2. 结果摘要

| 类型 | 结果 | 说明 |
| --- | ---: | --- |
| 功能覆盖率 | 100% | 7 个 covergroup type，65/65 个计划 bin 命中 |
| 断言覆盖率 | 100% | 42/42 条 assertion 有有效尝试，failure count 均为 0 |
| Cover directive | 100% | 14/14 条 cover property 命中 |
| RTL FSM 状态 | 100% | 5/5 个状态命中 |
| RTL FSM 转换 | 87.5% | 8 个转换中命中 7 个；缺项来自防御性/default 路径 |

完整工程按文件统计的 code coverage 为 58.7%，这个数字包含 UVM package、testbench、接口和大量不会在普通回归中执行的库式代码，不作为 DUT 的验收指标。核心 RTL 改用 `config/rtl_coverage_policy.psd1` 的逐模块门禁，本轮 17/17 通过。

| 设计单元 | Statement | Branch | Condition | Expression | FSM | Toggle |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `apb_uart` | 100% | 98.0% | 100% | 96.4% | 无状态机 | 38.7% |
| `async_fifo` | 100% | 100% | 50.0% | 100% | 无状态机 | 91.6% |
| `reset_sync` | 100% | 100% | 无有效项 | 100% | 无状态机 | 100% |
| `uart_rx` | 95.6% | 94.1% | 57.1% | 100% | 90.0% | 100% |
| `uart_tx` | 95.0% | 91.6% | 50.0% | 100% | 100% | 96.5% |

## 3. 本轮补测和模型调整

第一次合并时，功能覆盖率为 87%。检查报告后确认有两类原因：

1. UART 数据 coverpoint 把 1 到 254 拆成逐值 bin，要求小型回归遍历全部字节并不符合本项目“代表值与边界值覆盖”的计划；现已改为 zero、ff、low、mid、high 五组。
2. APB 地址/错误 cross 包含 CTRL、BAUD 报错两个规格上不可能出现的组合；现已明确 ignore。同时发现 RXDATA 写操作确实漏测，已补入 `uart_bad_access_test`。

调整后重新执行完整回归并合并，功能覆盖率达到 100%。这里没有删除真实缺口：RXDATA 写是通过补测试关闭，只有规格明确不可能的 CTRL/BAUD error 被忽略。

## 4. Code coverage waiver

以下未覆盖项暂不通过强制内部信号或篡改状态来制造命中：

- `uart_tx`、`uart_rx` 的 `unique case default`：状态变量使用枚举，并由复位和合法状态转换控制；命中 default 需要人为破坏状态编码，属于故障注入而不是正常功能测试。
- `apb_uart` 的低 toggle coverage：CTRL 只有低 3 位有效，常用 BAUD 值也集中在低位；32 位总线和寄存器的高位不需要为了 toggle 数字逐位翻转。
- `uart_baud_gen` 的 BAUD=0 防御分支在集成层不可达，因为 APB 寄存器会先把 0 规范化为 1；该项登记为 `RTL-COV-W004`，branch 实测 85.7%，门槛 85%。
- 部分 condition/expression 组合：短路表达式并非所有真值组合都有独立功能含义。功能结果、分支和相关断言已经覆盖；TX 数据位故障注入也已证明 scoreboard 能够检出数据路径错误。

## 5. 当前结论

按本项目已定义的功能范围，functional coverage 和 assertion coverage 已关闭；DUT 核心模块 statement coverage 为 95% 以上，未覆盖分支主要是防御性 default。覆盖率结果已足以作为论文实验数据，但不能替代静态 CDC 检查，也不能证明未定义的生产级 UART 功能。
