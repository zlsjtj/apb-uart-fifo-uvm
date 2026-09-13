# 当前架构与后续工作

这是当前说明入口。历史 P0/P1 结果见 p0_p1_finish_result.md，9 月 5 日基线见 p0_p2_contract_closure.md；数字只属于各自记录的运行。

本轮工程整理与两轮 12/12 验收记录见 engineering_delivery_result.md。

## 架构

DUT 顶层连接 APB 寄存器、配置邮箱、TX/RX 异步 FIFO、发送完成 CDC 和 UART 收发核心，并处理复位与状态同步。寄存器地址、位定义、默认值集中在 apb_uart_reg_pkg。APB 为零等待接口，读数据和错误响应必须在传输完成沿之前有效。

UVM 侧由 APB/UART agent 产生和监视引脚事务。predictor 推导期望，scoreboard 比较数据；RAL 通过 APB monitor 被动更新；统一 reset monitor 通知模型、scoreboard、coverage 和 RAL。内部探针只服务配置与 CDC 的白盒检查，不给串行数据检查器提供答案。

配置模型区分“请求值”和“公开 STATUS 已确认完成的值”。串行 monitor 每帧冻结参数，并用 reset epoch 丢弃被复位打断的帧。把 APB 写成功立即当成 UART 配置生效的做法已经停用。

本轮补充 STATUS.TX_BUSY，由 APB 接收计数和 UART 完整停止位后的完成计数产生，完成计数用 Gray 编码返回。它不复用 FIFO empty，也不把开始输出停止位当成发送结束。普通配置流程先排空 TX，外部 RX 的空闲由通信协议保证。

白盒配置 monitor/checker 已移至 env 层并带开关。关闭时顶层不实例化探针接口和集成白盒断言，UART agent 的引脚事务仍照常流向 predictor/scoreboard。FIFO 深度由顶层参数传到共享 env_cfg，再传到满空和回绕激励，避免硬编码 16。

## 工程运行与当前结果

工具路径和器件集中配置，完整验收先检查版本、器件支持与实际仿真启动，再在独立快照里运行。固定种子保留缺陷复现基线，expanded 模式扩展压力与 mutation 种子，正确和故障版本仍成对运行。

- 最近一次尝试：reports/acceptance_summary.json。RUNNING 或 FAIL 不是已交付版本。
- 最近成功交付：reports/published/latest.json，明确给出 runId、源码身份和交付清单哈希。
- 完整本地证据：deliveries/<runId>；论文结果表为其中的 paper_results.md。
- 图示：architecture_figures.md；配置和命令：reproduction_and_delivery.md。

不要从工作区 reports 下的零散历史文件拼接当前结论。交付包只从选定快照取文件，源码身份与整个包的完整性分别校验。资源以 utilization.rpt 的 Slice 指标为准，OOC WNS 不是板级最高频率。

## 毕设还要补什么

现有题目侧重 UVM 验证，不要求把 UART 变成产品级 IP。后续先整理需求追溯、APB 缺陷闭环案例、CDC 路径依据、覆盖率与 mutation 的证据，再形成论文正文和答辩演示。导师如果要求上板，应另立板级阶段，先完善真实异步 RX，再做板卡约束、实现、bitstream 和串口实测。没有这些证据时，论文明确写仿真和综合范围，不作板级可靠性结论。

商业 CDC/RDC 分析、布局布线和上板不是同一个验收层次，不能用其中一项代替另一项。
