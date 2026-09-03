# CDC 结构审计说明

## 1. 审计范围

本项目包含 `pclk` 和 `uart_clk` 两个异步时钟域。当前开发环境只有 ModelSim/Questa 仿真和覆盖率工具，没有可调用的 Questa CDC、SpyGlass 等商业 CDC 工具。因此本次结论来自 RTL 结构审计、同步器标注、断言和动态回归，不把它表述为芯片流片级 CDC signoff。

结构检查命令如下：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_cdc_structural_check.ps1
```

本轮结果为 22/22 通过，详见 `reports/cdc_structural_summary.md`。

## 2. 跨时钟路径与处理方式

| 路径 | 方向 | 当前处理 | 审计结论 |
| --- | --- | --- | --- |
| TX FIFO 数据与状态 | `pclk` → `uart_clk` | 异步 FIFO，Gray 指针两级同步 | 保留原有结构，并补充 `ASYNC_REG` 标注 |
| RX FIFO 数据与状态 | `uart_clk` → `pclk` | 异步 FIFO，Gray 指针两级同步 | 保留原有结构，并补充 `ASYNC_REG` 标注 |
| CTRL、BAUD 配置 | `pclk` → `uart_clk` | 稳定数据束加请求/应答翻转邮箱 | UART 域一次性接收 CTRL 与 BAUD 快照 |
| RX FIFO full 状态 | `uart_clk` → `pclk` | 两级单比特同步 | STATUS 使用同步后的标志 |
| frame error 状态 | `uart_clk` → `pclk` | 两级单比特同步 | STATUS 使用同步后的标志 |
| IRQ | `pclk` 域内 | 由 `irq_en` 和 `rx_empty` 生成 | 不属于跨时钟路径 |
| 双域复位 | 两域 | 外部复位异步断言，各目标域经两级同步器释放；任一外部复位都会清空两个 FIFO | 动态测试覆盖三种 reset 场景，并用 SVA 检查断言与释放条件 |

## 3. 本轮 RTL 修正

原实现对 3 位 CTRL 与 32 位 BAUD 分别进行两级同步。该做法对单个比特的亚稳风险有帮助，但多个位可能在不同 UART 时钟边沿到达，无法保证同一份配置快照。

现在的配置邮箱由 APB 域保存 `cfg_ctrl_hold` 和 `cfg_baud_hold`。发起请求后，数据束保持不变；UART 域把请求翻转同步两级后再采样整份数据，并回传应答。若软件在应答返回前继续写 CTRL 或 BAUD，当前在途请求不会被破坏，后续只发送最新寄存器值。这样避免了多位配置半新半旧的情况。

另外，RX FIFO 的 `full` 与接收器的 `frame error` 原来直接被 APB STATUS 读取。它们现在先同步到 `pclk`，使软件可见状态不依赖异步信号的即时电平。

复位路径也做了同样的域划分。`presetn`、`uart_rst_n` 仍可立即把对应逻辑拉入复位，但释放要经过目标时钟域内的两级同步器。FIFO 的原始复位源仍是 `presetn && uart_rst_n`，所以任一外部复位都能整体清空 FIFO；送到读写两侧的则分别是 `pclk` 和 `uart_clk` 同步释放后的复位。这样既保留原有清空语义，也避免组合复位在时钟边沿附近直接释放。

## 4. 验证证据

- `uart_baud_timing_test`：BAUD=0/1/4/8 的 TX 位宽保持正确；
- `uart_reset_cdc_test`：双复位、APB-only reset、UART-only reset 后均能恢复；
- `uart_frame_error_test`、`uart_rx_fifo_full_test`：新增 STATUS 同步后，坏帧与 RX 满状态仍正确；
- 2026-09-03 的三组 seed 正式回归为 45/45 PASS，所有 warning、error、fatal 均为 0；
- 合并 45 个 UCDB 后，功能覆盖 65/65，断言 42/42，cover property 14/14，均为 100%；
- `uart_config_latency_test` 明确记录 APB 写完成与 UART 域 `cfg_apply` 的时刻，证明配置经过邮箱后才在目标域生效；
- 复位定向测试另在三种时钟配置下通过：默认配置以及两组非整数时钟比和错相配置。

## 5. 边界与后续要求

当前配置邮箱保证跨域传递的原子性，但并不支持在一个正在发送或接收的 UART 帧中切换 BAUD。软件应在帧间配置 CTRL、BAUD；这也是本项目已经声明的接口使用约束。

当前已经完成 RTL 层面的异步断言、同步释放，但动态回归和文本结构检查仍不能替代库单元恢复/移除时间、约束文件和专用 RDC/CDC 工具的静态检查。若学校或实验室能够提供 CDC/lint 工具，下一步应在同一版 RTL 上运行商业 CDC 与 reset-domain 分析，并把未处理告警逐项记录。
