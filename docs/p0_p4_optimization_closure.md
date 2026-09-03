# P0—P4 优化收口记录

这轮工作的重点不是继续堆测试数量，而是把设计和验证环境中容易“互相迁就”的地方拆开，并让回归结果有统一、可复查的入口。

## P0：黑盒串行检查与白盒探针分开

TX、RX monitor 现在只读取公开的 `uart_if` 引脚，并使用 APB monitor 更新的 `uart_serial_cfg` 计算采样节拍。它们不再读取 `uart_probe_if`、DUT 内部 BAUD 或配置生效信号。因此，内部 CDC 或波特率实现出错时，串行检查器不会跟着错误实现一起变化。

`uart_probe_if` 仍然保留，但用途收窄为配置跨域时延、CDC 断言和调试定位。白盒信息可以帮助解释问题，不能充当数据正确性的标准答案。

## P1：统一复位观察源

新增 `uart_reset_monitor`，把 APB reset、UART reset 及同时复位统一转成 reset transaction。predictor、scoreboard、coverage 和 RAL mirror 都从这一路接收复位事件。

过去测试中显式调用 `env.regmodel.reset()` 的做法已经删除。现在 RAL mirror 是否复位，取决于被动观察到的 APB reset，而不是测试代码事后修正模型。UART-only reset 只清理跨域数据状态，不会错误重置 APB 配置模型。

## P2：拆分 DUT 职责

原先集中在 `apb_uart.sv` 的逻辑拆成四层：

- `apb_uart_regs.sv`：APB 地址译码、寄存器、读写错误和 FIFO push/pop；
- `apb_uart_cfg_cdc.sv`：CTRL/BAUD 稳定数据束和请求/应答邮箱；
- `uart_baud_gen.sv`：波特率分频计数；
- `apb_uart_serial_core.sv`：TX、RX、loopback 和串行侧 FIFO 握手。

`apb_uart.sv` 只保留复位同步、状态同步、FIFO 和子模块连接。拆分后的接口语义没有改变，原有 SVA 探针名称也保留在集成层。

## P3：单一回归计划

`config/verification_plan.psd1` 是测试清单和压力时钟配置的唯一来源。普通回归、三 seed 正式回归和一键验收都读取这份文件，不再各自保存测试列表或写死 16/48 等数量。以后新增测试时，只需修改计划文件，脚本会按实际条目数检查完整性。

## P4：RTL 覆盖率门禁

`config/rtl_coverage_policy.psd1` 保存核心 RTL 的 statement、branch 和 FSM 阈值，`generate_rtl_coverage_gate.ps1` 从按设计单元生成的覆盖率报告中逐项判定，并同时输出 Markdown 和 JSON。

门禁共有 17 项，本轮全部通过。`uart_baud_gen` 有一个集成级不可达分支：APB 寄存器层会先把 BAUD=0 规范化为 1，因此 0 不会送到波特率子模块。该防御分支保留，并以 `RTL-COV-W004` 单独登记。toggle、非法状态 default 和无独立功能意义的短路组合也都有明确 waiver；这些内容没有被包装成“100% 代码覆盖”。

## 本轮验证结果

- PowerShell 脚本语法检查全部通过；
- 架构规则 37/37、RAL 规则 16/16、CDC 规则 22/22、P2 规则 15/15；
- 定向冒烟 5/5；
- 三组 seed 正式回归 48/48，warning、error、fatal 均为 0；
- 两组错相异比时钟压力场景 10/10；
- 四类 mutation 全部检出，mutation score 为 100%（仅限所选四种故障）；
- 功能覆盖 65/65、断言 42/42、cover property 14/14；
- RTL-only coverage gate 17/17。

以上结论属于仿真、结构审计和覆盖率闭环，不等同于商业 CDC/RDC signoff，也不证明该教学 UART 已达到生产 IP 标准。
