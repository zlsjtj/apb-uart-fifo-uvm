# 验证平台架构优化说明

## 1. 优化目的

P2 已经把 predictor 和 scoreboard 分开，也增加了独立 RX 引脚 monitor。这一轮继续处理几个容易在后续扩展中出问题的地方：driver/monitor 复用 DUT 内部节拍、白盒信号散落在公共接口中、验证参数重复定义，以及复杂测试仍由 test 直接调度底层 sequencer。

本轮没有改变 UART 的功能规格。RTL 仍是 1 个起始位、8 个数据位、1 个停止位的简化模型，BAUD 仍按 UART 时钟周期计数。

## 2. 串行 BFM 不再读取 bit_tick

TX 和 RX monitor 现在只使用以下可观察信息：

- `tx_o` 或 `rx_i` 引脚电平；
- UART 域已经生效的 BAUD 配置；
- `uart_clk`；
- UART 域 enable 状态。

monitor 先检测空闲高电平到起始低电平的跳变，再根据生效 BAUD 计算每个串行位应跨越的 UART 时钟数，依次采样 8 个数据位和停止位。UART driver 也用环境时钟参数和 transaction 中的 `bit_cycles`、`edge_offset_ps` 生成波形，不再等待 DUT `bit_tick`。因此 DUT 的波特率节拍即使实现错误，也不会带着激励端一起错。

这样可以避免 DUT 节拍和 monitor 同时使用一条错误内部信号。配置在一帧开始时取快照，符合项目已经声明的“只在帧间更新 BAUD”约束。

需要说明的是，这仍是适配当前简化 RTL 的同步采样模型，不是带半位确认和 16 倍过采样的生产级 UART monitor。

## 3. 统一环境配置

`uart_env_cfg` 集中保存 FIFO 地址宽度、两个时钟半周期和初始相位。顶层使用同一个 `FIFO_ADDR_WIDTH` 同时配置 DUT 和 UVM 环境。当前 RTL 固定为 8N1，因此数据位和停止位放在寄存器定义 package 中作为能力常量，不再伪装成运行时可配置项。

predictor 不再写死 16 项 RX FIFO，而是调用 `cfg.fifo_depth()`。如果以后修改 FIFO 参数，参考模型会使用相同配置。配置对象还会在环境构建阶段检查时钟参数不能为 0。

## 4. 文件和多接口序列结构

原来的 `uart_sequences.svh` 有 800 多行，`uart_tests.svh` 接近 600 行。现在两个文件只保留兼容 include，具体类按功能放在：

```text
tb/uvm/sequences/
  uart_base_reg_sequences.svh
  uart_functional_sequences.svh
  uart_rx_fifo_sequences.svh
  uart_reset_timing_sequences.svh
  uart_misc_sequences.svh

tb/uvm/tests/
  uart_base_reg_tests.svh
  uart_functional_tests.svh
  uart_cdc_timing_tests.svh
  uart_misc_tests.svh
```

新增 `uart_virtual_sequencer`，统一保存 APB、UART sequencer 和 reset 接口。外部 RX、帧错误、RX FIFO 满以及 reset/CDC 场景都由 virtual sequence 协调总线、串行和复位动作，test 只负责选择场景和参数。

公共 `uart_if` 只保留引脚、时钟和复位。配置邮箱、目标域生效值、FIFO 状态等内部观察点集中到 `uart_probe_if`，所有 DUT 层次引用集中在 `tb_apb_uart.sv`。这样可以明确区分黑盒数据检查和用于解释 CDC/配置时序的白盒探针。

## 5. 一键验收和 mutation 矩阵

`scripts/run_acceptance.ps1` 是新的总入口，依次执行：

1. 架构结构检查；
2. 三组 seed 的完整回归和覆盖率合并；
3. 两组非整数时钟比、错相压力回归；
4. 四类 mutation。

mutation 现包含 TX 数据位翻转、IRQ 恒低、FIFO full 恒低和 baud tick 过快。`run_mutation_suite.ps1` 生成统一矩阵，给出测试、seed、主要检出器和 mutation score。该分数只针对这四个预先选定的故障模型，不能解释为穷尽性故障覆盖率。

## 6. 架构边界

这一轮提高的是验证独立性、配置一致性和工程可维护性，没有把简化 UART 扩展为生产级 IP。商业 CDC/lint、门级仿真、综合时序和 FPGA 板级测试仍不在现有证据内。论文中应继续把这些内容列为边界，而不是用 100% 功能覆盖率替代它们。
