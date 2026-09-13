# CDC/RDC 路径说明

本项目有 pclk 和 uart_clk 两个时钟域。本文件说明当前实现和路径分类，不把仿真、结构正则检查或 Vivado report_cdc 称为商业 CDC/RDC signoff。

## 路径及约束

| 路径 | 当前处理 | 需要核对的条件 |
| --- | --- | --- |
| TX/RX FIFO 指针 | 源域寄存的 Gray 指针，两级 ASYNC_REG 同步 | 源域每次最多加一；目标域允许跳过中间码；实现时保持总线位间偏差约束 |
| TX/RX FIFO 数据 | 双时钟存储与同步指针配合，非空才允许读取 | 写入完成先于读侧获得非空；数据不得逐位加同步器 |
| CTRL/BAUD 数据束 | hold 寄存器加 req/ack 翻转握手 | 在途数据保持；接收端只在同步请求变化后装载 |
| RX full、TX empty | 源域标志寄存后，两级返回 pclk | STATUS 反映有同步延迟的状态，不是瞬时占用快照 |
| TX 完成计数 | UART 完整停止位或显式中止后递增，源域 Gray 编码后两级返回 pclk | APB 侧本地计数成功写；计数宽度为 ADDR_WIDTH+2，覆盖 FIFO、活动帧及完成流水级余量 |
| frame error | UART 域寄存后两级返回 pclk | 错误保持到后续有效帧、disable 或 reset |
| reset | 异步拉低、各域两级同步释放 | 任一外部 reset 清空 FIFO、串行状态及邮箱；UART-only reset 保留 APB 配置 |
| IRQ | pclk 域的 irq_en 与 RX empty 组合 | 不跨时钟域 |

TX_EMPTY 表示 FIFO 空，不代表线上发送完成。STATUS[7] TX_BUSY 比较 APB 已接收计数与返回的完成计数，避免刚写入时从 UART 域返回的旧 idle 值误报完成。普通软件更改 BAUD 前等待 TX_BUSY=0 与 CFG_BUSY=0，并保证外部 RX 无在途帧；配置写后再次等待 CFG_BUSY=0。显式 disable/reset 的清空或中止不能解释为数据成功送达。

UART-only reset 时 APB 寄存器仍可读写，但 FIFO 尚未释放期间 TXDATA/RXDATA 必须返回 PSLVERR，且不能产生 push/pop。此时写入的 CTRL/BAUD 在复位恢复握手中重新发送。独立协议测试和 uart_frame_reset_test 都检查了这条边界。

## 配置恢复为什么要改

旧实现第一次离开复位就直接读取 hold 数据，绕过了两级请求同步。现在邮箱两端都使用共享复位的本域同步版本。复位时 pending 置位，释放后源域重新取 APB 寄存器快照、翻转 req；目标域等待同步后的 req，再装载、返回 ack。首次配置和后续写入使用同一条通路。

UART-only reset 不清 APB 寄存器，因此握手恢复的是保留下来的寄存器值；APB reset 则恢复默认配置。忙时连续写可以合并为最新值，不保证每个中间值都会被目标域采用。

STATUS[6] 为 CFG_BUSY，包含在途请求和待发送更新。软件完成最后一次配置写后，应轮询该位清零再启动串行流量；配置仍限定在帧间修改。

## 报告如何判定

run_cdc_structural_check.ps1 只检查必要结构和连接，不能证明电路没有漏网路径。run_vivado_synth.ps1 生成实际综合网表报告，check_cdc_paths.ps1 按 config/cdc_path_policy.psd1 检查告警的源和目标端点：

- Critical 一律拒绝。
- Warning 必须唯一匹配已说明的路径类别；新增或改名路径不会自动继承豁免。
- 解析行数必须与报告摘要相等，空报告或漏解析不能通过。
- 原始报告保留，不使用关闭检查或删报告的方式得到“零告警”。

原来 RX full 的组合逻辑前同步告警，通过源域标志寄存消除。旧 RX FIFO 数据到 APB 响应寄存器的 8 条 Critical，在修正零等待 APB 为组合响应后不再以跨域寄存器路径出现；这不是数据路径消失。RXDATA 仍必须依靠 FIFO 非空条件和同步写指针保护，独立 APB 完成沿测试检查出队数据及回绕顺序。

## 综合和硬件边界

constraints/synth_ooc.xdc 是教学接口时序预算，不是板级约束。rx_i 按同步采样的教学接口约束到 uart_clk；当前接收器不具备完整异步输入同步、起始位中心定位和过采样。故不能用本 CDC 报告的内部路径结果证明真实外部 UART 接口可靠。

综合流程不再用 set_clock_groups 一刀切所有跨域数据路径。单比特控制只对第一级同步器 D 端设 false path；Gray 指针既设 10 ns 的 datapath-only max delay，也设 10 ns bus_skew；配置数据束和 TX FIFO 数据限制为 40 ns，RX FIFO 到 APB 组合输出限制为 10 ns。这样数据稳定窗口有显式时序预算，不会被异步时钟组覆盖掉。

这些约束在综合网表上检查并保留到 checkpoint；布局布线后仍需复查。门级亚稳行为、商业 RDC/CDC signoff、具体板卡和实测均未在本轮完成。

TX 完成计数使用同样的 10 ns max_delay 和 bus_skew 预算，新增路径必须匹配 CDC-W004。目标域采样可能跨过多个 Gray 值，不要求目标域相邻采样值只有一位变化；单步 Gray 断言只在源域检查。
