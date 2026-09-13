# 需求—验证追溯矩阵

本表描述当前修改后的验证机制。每个“通过”结论都必须能在 reports/acceptance_summary.json 指向的独立运行目录中找到；历史 PASS 不自动延续到修改后的源码。

| 需求 | 当前实现与检查 | 对应测试/门禁 | 证据 |
| --- | --- | --- | --- |
| RQ-01 寄存器与 APB 协议 | 完成沿前组合响应，clocking block 严格采样，同拍错误 SVA；RAL 前门和被动镜像 | uart_reg_test、uart_ral_test、独立 apb_contract_tb、apb_late mutation | contract_tests.json、正式回归、mutation_campaign.json |
| RQ-02 APB 到 TX 数据顺序 | 成功 TXDATA 写形成期望，独立 TX 引脚 monitor 解码 | loopback、random、baud_timing，TX/baud mutation | scoreboard、功能覆盖及匹配错误记录 |
| RQ-03 外部 RX 和 loopback | 配置确认后才启动 RX；独立引脚 monitor；predictor 与纯比较 scoreboard 分离 | external_rx、external_rx_baud、frame_error、rx_fifo_full | 正式回归和错相子集 |
| RQ-04 FIFO 边界与参数 | 源域满空标志寄存、Gray 同步、受限访问无副作用；ADDR_WIDTH=1 的比较不使用负下标 | FIFO 满空测试；宽度 1..16 elaboration，1/2/4/6 另作多次回绕 | contract_tests.json 明确区分测试深度 |
| RQ-05 IRQ 和状态 | IRQ 本域产生，RX full/frame error/TX empty 同步返回；CFG_BUSY 为动态位 | irq、frame_error、RAL；IRQ/FIFO/frame error mutation | 正式回归、SVA、campaign |
| RQ-06 配置与位宽 | 请求配置与确认配置分离；STATUS.CFG_BUSY 包含 pending；帧开始冻结参数 | config_latency、config_stress、baud_timing | 配置时延、位宽、握手 SVA |
| RQ-07 CDC/RDC 与复位 | 邮箱首次恢复使用正常握手；任一 reset 中止串行/FIFO/邮箱状态；monitor 使用 reset epoch | reset_cdc、frame_reset、config_stress；结构和综合网表路径分类 | cdc_review.json、35 项结构规则、两组错相子集 |
| RQ-08 检查器有效性 | 每个 mutation 的同测试同 seed 基线必须通过；错误记录需匹配具体 detector | campaign 和门禁反向测试 | matchedFailureLines、baselinePass |
| RQ-09 覆盖率判定 | UCDB 必须存在；功能 bin、cover directive、assertion 及 RTL 阈值分别检查 | merge_coverage、functional_assertion_gate、rtl_coverage_gate | 原始 UCDB、text/HTML、JSON 门禁和 waiver |
| RQ-10 可复现性 | 每轮隔离源码与结果；起止源码哈希一致；RUNNING/FAIL/PASS 全部落盘 | run_acceptance、源码漂移和旧 PASS 反向测试 | runId、source.sha256、逐步日志及独立目录 |
| RQ-11 发送完成 | 接收计数与完整停止位后的 Gray 完成计数比较；普通配置先等待排空 | tx_completion、tx_early_complete mutation、APB unit 的数据位/停止位中止 | 正式回归、mutation、contract_tests |
| RQ-12 可复用与参数 | agent 无探针依赖；独立无探针编译；四种深度和独立 FIFO 队列检查 | no_probe、fifo_wrap、满空和复位子集、async_fifo_random_tb | parameter_regression/summary.json、fifo_unit_tests.json |

## 尚不能据此证明的内容

- RX 仍是教学同步采样模型，不代表真实异步串口的抗亚稳、采样相位和波特率容差。
- Vivado CDC 路径分类不等于商业 CDC/RDC signoff。RXDATA 的组合输出还必须结合 FIFO 读契约解释，不能只看工具告警是否消失。
- OOC 综合的资源和 setup WNS 不等于布局布线、bitstream 或上板实测。
- 功能覆盖和 mutation 只覆盖计划中的场景与故障；不能推导为无缺陷证明。
- 本轮按用户要求不 commit、不 push。基线提交和本轮源码哈希应分开记录。

## 本轮相对历史版本的变化

历史工作完成了寄存器 package、RAL、独立 monitor、复位同步和声明式回归，但仍存在 APB 晚响应与 BFM 延迟采样共同盲区。本轮用独立协议测试定位，并同步修正 RTL、BFM、SVA 和 mutation；同时收紧了配置恢复、参数范围、门禁判定和证据归属。详细机制见 p0_p2_contract_closure.md 与 bug_closure_case.md。
