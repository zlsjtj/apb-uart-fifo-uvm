# P0/P1/P2 接口与证据收口

本轮基于 `5214f53` 开始。用户要求先完成修改和多轮本地测试，不提交 commit，也不 push。

## 范围和验收

| 项目 | 改动 | 验收条件 |
| --- | --- | --- |
| P0 APB | 完成沿前返回数据和错误，driver/monitor 使用 clocking block 的 #1step 采样 | 原先 BAUD 读 0 的问题消失；连续访问和非法访问通过；晚响应 mutation 被检出 |
| P0 CDC/RDC | FIFO 状态源域寄存；TX empty 返回域同步；邮箱两端统一复位并用正常握手恢复 | 无未分类 Critical；复位和首次配置请求无越过握手的装载 |
| P0 复位中的 APB 访问 | UART-only reset 时保留配置访问，但拒绝 FIFO 数据访问 | PSLVERR 同拍有效，push/pop 为 0，配置写入在恢复时重放 |
| P1 配置与复位模型 | STATUS[6] 提供 CFG_BUSY；参考模型根据成功写和公开 busy 清零确认配置；复位 epoch 中止旧帧 | 相邻配置/帧与帧中复位测试通过；数据检查不读取内部配置 |
| P1 参数和门禁 | 深度 2 的 FIFO；独立协议测试；mutation 基线、失败行匹配；验收失败落盘；证据隔离 | 参数测试及门禁反向测试通过；过期/缺失/无关失败不能算 PASS |
| P2 综合和文档 | 真实 OOC；约束前置；资源按利用率报告统计；路径逐条分类 | 综合、时序及 CDC 路径审核均有报告，文档与实际实现一致 |

跨域时序只对单比特控制同步入口设 false path；配置数据束、FIFO 数据和 Gray 指针使用明确的 datapath max delay，Gray 另设 bus_skew，不用宽泛时钟组遮掉数据路径约束。

当前仍按简化 8N1 教学模型定位，不在本轮加入 16 倍过采样、板级约束和上板测试。综合后的时序估算不是实际板级最高频率。

## 结果

本轮已完成。最终验收运行号为 `20260905_121555_08b361cd`，总耗时 602.8 秒，8/8 个步骤通过。

| 检查 | 最终结果 |
| --- | --- |
| RTL lint | 0 error、0 warning |
| 结构审计 | CDC/RDC 35/35、RAL 16/16、架构 45/45、P2 21/21 |
| APB 与 FIFO 参数 | 地址宽度 1..16 全部编译展开；宽度 1/2/4/6 另做连续访问、两次回绕和复位期间拒绝访问 |
| 完整回归 | 基准 seed 401/501/601，共 54/54，通过时 warning/error/fatal 均为 0 |
| 错相压力 | 两组不同周期与初相位，共 14/14 |
| 功能覆盖 | 65/65 个 bin |
| 断言和 cover property | 57/57、16/16；正常回归未报 assertion error |
| RTL 覆盖率门禁 | 17/17；保留原有明确 waiver，没有下调门槛 |
| 故障对照 | 12/12 KILLED，12 个同测试同 seed 的正确基线全部通过 |
| 门禁反向测试 | 19/19 |
| Vivado CDC 路径 | 59/59 完成分类，无 Critical，无未审核 Warning；保留 46 条已说明的 Warning |
| OOC 综合 | 249 Slice LUTs、274 Slice Registers，其中 16 LUT as Memory；总体 setup WNS 为 +1.414 ns |

前一轮完整验收 `20260905_115806_d22fd30d` 也为 8/8 PASS，使用基准 seed 101/201/301。此后补入了 UART-only reset 期间的 FIFO 访问保护、APB 未知响应断言、旧 mutation 入口统一和更细的跨域时序约束，再执行上述最终验收。两轮是不同源码版本，不能把 108 次正式回归都算作最终版本的测试。

最早一次独立验收曾因 PowerShell 参数被拆成字符而失败，失败记录 `20260905_115556_c1bf0f74` 保留。该问题修复后，1..16 的参数矩阵在后续完整验收中通过，没有把旧 PASS 当作修复证据。

## 证据位置与版本

- 最终汇总：`reports/acceptance_summary.json`。
- 完整隔离目录：`reports/acceptance_runs/20260905_121555_08b361cd/workspace`。
- 常用报告目录已同步为最终结果：`reports/final_regression`、`reports/stress`、`reports/synthesis`，以及 `reports/mutation_campaign.json`、`reports/contract_tests.json`、`reports/evidence_gate_selftests.json`。
- RTL、TB、脚本、配置和约束的 SHA-256 汇总：`a6461b0f482f102709197a96297c30d5338af76b639a66cfc4caeec9561f2a17`。验收前后与当前工作区一致；逐文件清单在 `reports/final_regression/source_manifest.json`。
- 本轮未 commit、未 push，HEAD 仍为 `5214f53`，修改保留在工作区。

综合约束已经改变，不能把此次 WNS 或推算频率与旧版未完整约束的数字直接当作性能对比。此处只说明当前教学接口时序预算满足；布局布线、真实异步 RX 和板级性能仍需单独验证。
