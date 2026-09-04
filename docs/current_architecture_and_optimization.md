# 当前架构与本轮优化

## 现在的结构

项目已经不是“一个 UART RTL 加几个测试”的小样例，而是一套能独立运行的验证工程。DUT 侧按职责分成 APB 寄存器、配置跨时钟邮箱、异步 FIFO、波特率发生器和 UART 收发核心；验证侧按 APB agent、UART agent、参考模型、scoreboard、覆盖率、寄存器模型和白盒断言分层。正常功能检查只看总线与串行引脚，内部探针只用于 CDC、复位和配置生效时刻的检查。

一键入口是 `scripts/run_acceptance.ps1`。测试清单、错相时钟配置、覆盖率门禁和 mutation 清单都由配置文件维护，脚本不再写死测试数量。

## 原来的五个主要不足

### 1. 静态检查缺少固定入口

以前有 CDC 结构规则，但 RTL lint、报告格式和 signoff 边界没有放在同一条流程里。现在增加了 `run_static_checks.ps1`：RTL 使用 Questa/ModelSim 的 `-lint -pedanticerrors -warning error` 编译，结果必须是 0 error、0 warning；CDC/RDC 结构检查同时输出 Markdown 和 JSON。

这里仍要说清楚：结构规则能发现同步器遗漏、旧式逐位同步、复位直接释放等问题，但不能代替商业 CDC 工具的路径分类、waiver 审核和最终 signoff。

### 2. 没有可复现的综合与 QoR 证据

现在使用 Vivado 2023.2 对 `apb_uart` 做通用 Artix-7 器件 `xc7a35tcpg236-1` 的 RTL 综合，固定 PCLK 10 ns、UART clock 40 ns，并输出 utilization、timing summary、CDC 报告和机器可读 QoR。

第一次综合发现 FIFO 存储数组与异步复位写指针共用时序块，工具把 RAM 拆成了触发器。本轮把存储写入拆为无复位时序块，复位只清指针；旧数据在指针清零后不可达，功能语义不变。调整后工具能够推断两组 16×8 distributed RAM。综合单元统计从 410 个 LUT cell、558 个时序单元降到 312 个 LUT cell、326 个时序单元；PCLK 综合后估算上限从约 227.7 MHz 提高到约 251.6 MHz。

当前约束下 PCLK WNS 为 6.025 ns，UART clock WNS 为 31.993 ns。它们只是综合后基线，不是布局布线后的频率，更不是开发板实测结果。

综合本身是 0 error、0 critical warning，保留了 5 条普通 warning：`pready` 固定为 1、未使用的内部 `cfg_busy` 端口和小设计无法并行综合，部分信息在优化阶段重复出现。这些不影响综合网表生成，但原始日志仍随报告保留，没有把告警隐藏掉。Vivado 启动时另有两条用户配置目录只读提示，属于本机环境，不是 RTL 告警。

### 3. 配置切换和 reset 竞争覆盖不够

新增 `uart_config_stress_test`，连续写 BAUD/CTRL，让后续写入命中邮箱 busy 和 pending 合并路径，并检查 UART 域最终收敛到 APB 寄存器的最后值。用例还覆盖两种竞争：请求进行时触发 APB reset，以及保留 APB 寄存器时单独触发 UART reset。

串行 TX/RX monitor 也改为在检测到一帧开始时拍下配置快照。这样一帧传输过程中即使软件改 BAUD，monitor 仍按帧开始时的配置解码，不会把中途变化错误地带进当前帧。

### 4. 配置邮箱和复位的性质检查不够完整

配置 CDC 新增了 payload busy 期间稳定、request 最终得到 ack、pending 信号无未知态、apply 单周期、ack 变化必须伴随 apply 等断言。四路同步复位增加了“外部复位释放后至少保留同步延迟”的性质，既检查异步拉低，也检查同步释放。

这些断言和定向用例互相补充：断言约束每一次握手，用例负责真正制造连续写和独立复位场景。

### 5. Mutation 范围太窄

mutation 从原来的四类扩展为十一类，覆盖 TX 数据、RX 数据、RX empty、FIFO full、IRQ 恒高/恒低、波特率过快、配置 apply 丢失、配置 ack 卡住、frame error 被屏蔽和复位直接释放。清单位于 `config/mutation_plan.psd1`，每一项都指定测试、seed 和主要检出器；结果同时写入 Markdown 和 JSON。

十一项全部被检出，mutation score 为 100%。这个分数只针对清单里的代表性故障，不能理解成“所有 RTL 错误都能抓到”。

## 本轮验收口径

- RTL lint：0 error、0 warning；
- 架构规则 45/45，RAL 规则 16/16，CDC/RDC 结构规则 30/30，P2 检查 21/21；
- 三组 seed 共 51 次正常回归，warning、error、fatal 均为 0；
- 两组错相异比时钟压力子集共 12 次；
- 功能覆盖 65/65，断言 51/51，cover property 15/15，RTL-only 门禁 17/17；
- 11/11 mutation 被检出；
- Vivado 通用器件综合通过，并形成资源、时序和 CDC 原始报告。

## 离本科毕业设计还差什么

工程实现和验证闭环已经足够支撑本科毕设的主体，接下来最大的缺口不再是继续堆测试，而是把工程证据组织成论文和答辩能讲清楚的材料：

1. 选定一块具体 FPGA 板卡，补齐引脚、时钟、约束、实现、bitstream 和上板串口收发证据；如果学校只要求仿真型课题，也应在论文中明确没有上板。
2. 若实验室有商业 CDC 工具，补一次正式 CDC/RDC 分析和 waiver；没有工具时，保留当前边界，不能写成“CDC 已 signoff”。
3. 把需求、架构、关键问题、优化前后 QoR、验证计划、覆盖率和 mutation 结果整理为论文图表，原始报告作为附录或答辩备查材料。
4. 增加一个有对照意义的实验，例如不同 FIFO 深度的资源变化，或者不同 PCLK 约束下的综合结果。不要只给单点数字。
5. 最后做一次从干净 clone 开始的复现实验，记录软件版本、命令、运行时间和 commit，确保导师或答辩老师能按说明复跑。

下一轮最值得做的是“具体器件实现与上板”，其次才是论文排版。现在继续增加同类型随机用例，收益已经明显低于补真实硬件证据。
