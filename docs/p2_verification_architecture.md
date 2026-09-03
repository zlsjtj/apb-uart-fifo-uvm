# P2 验证架构优化说明

## 1. 这轮解决了什么问题

原来的环境能够跑通外部 RX 和 loopback，但 RX 期望数据主要来自 driver 自己发送的事务。这样做适合早期联调，却存在一个明显问题：激励端如果生成错了内容，scoreboard 可能仍拿同一份错误内容作为期望值，检查独立性不够。

另外，原 scoreboard 同时接收激励、推导 FIFO 行为并比较结果，职责比较重。CTRL、BAUD 写入后还要跨到 `uart_clk` 域，过去的测试也没有把“APB 写完成”和“UART 域真正采用新配置”分开记录。

P2 的目标就是把这三个边界理顺，并用一项新的控制类故障注入验证检查链路。

## 2. RX 输入改为独立观察

`uart_rx_monitor.svh` 是一个只读 monitor。它直接观察 `rx_i`，根据 UART 域已经生效的 BAUD 配置和 `uart_clk` 识别起始位、8 个数据位和停止位，发布解码后的字节和帧错误标志。它不读取 driver 的 transaction，也不依赖 driver 内部队列和 DUT `bit_tick`。

因此，RX 期望值来自实际出现在引脚上的串行波形。driver 只负责产生激励，不再向检查端发布“标准答案”。坏停止位同样由 monitor 根据引脚采样得到，predictor 决定该帧是否应进入 RX FIFO 模型。

这仍然是与当前简化 DUT 匹配的同步监视器，不等同于真实 UART 的 16 倍过采样接收模型。若后续扩展 DUT，monitor 也要一起升级。

## 3. predictor 与 scoreboard 的分工

现在的数据流是：

```text
APB monitor ---------------------> predictor ---- expected TX ----+
TX serial monitor --------------> predictor                       |
RX-pin monitor -----------------> predictor ---- expected RX ----+--> scoreboard
UART config-apply monitor ------> predictor                       |
                                                                   |
TX serial monitor -------------------------------- actual TX -----+
APB monitor -------------------------------------- actual RXDATA --+
```

predictor 负责解释行为：

- APB 写 TXDATA 后生成预期 TX 字节；
- 根据 UART 域实际生效的 CTRL 判断 loopback 是否有效；
- 从独立 RX monitor 接收帧，拒绝坏帧，并按 16 深度维护 RX FIFO 抽象队列；
- RX FIFO 已满时记录预期丢弃；
- APB 读 RXDATA 时弹出一项预期 RX 数据。

scoreboard 只负责比较：

- 将 predictor 的 expected TX 与 TX monitor 的 actual TX 比较；
- 将 predictor 的 expected RX 与 APB monitor 看到的 RXDATA 比较；
- 仿真结束时检查是否还有未消费的期望值或实际值。

拆开后，模型规则和比较规则不再混在同一个类里。以后修改 FIFO 策略时主要改 predictor，修改报错与配对方式时主要改 scoreboard，定位问题更直接。

## 4. 区分 APB 写入和 UART 域生效

CTRL、BAUD 在 APB 域写入后，通过请求/应答邮箱跨到 UART 域。P2 在 UART 域配置真正装载时增加单周期 `cfg_apply_uart`，并同时暴露已经生效的 CTRL、BAUD 值。配置 monitor 只在这个事件出现时发布新配置，predictor 也以它作为有效配置边界。

`uart_config_latency_test` 单独记录两个时刻：

1. APB sequence 完成配置写入；
2. UART 域出现 `cfg_apply`，且生效值与目标值一致。

默认时钟的定向测试中，BAUD 从 APB 完成到 UART 生效相隔 50 ns，CTRL 相隔 130 ns。采用 APB 半周期 7 ns、UART 半周期 11 ns并设置不同初相位时，两项延迟分别为 58 ns 和 56 ns。结果不同是异步时钟和邮箱状态共同作用的正常现象，所以测试不规定固定延迟，只要求目标配置在 APB 完成之后生效。

SVA 同时检查 UART 域配置只能伴随 apply 事件变化，并检查 apply 时配置数据不含未知值。正式合并覆盖中，两条新增 assertion 均有有效尝试，新增 cover directive 也已命中。

## 5. 控制类故障注入

新增 `UART_MUTATE_IRQ_STUCK_LOW` 编译期开关，打开后强制 IRQ 输出为低。`run_control_mutation_check.ps1` 使用独立的 `work_irq_mutation` 库运行 `uart_irq_test`，只有检查器确实发现故障时脚本才返回成功。

本轮结果为 `PASS (mutation detected)`。故障同时触发了测试中的 `IRQ_STATUS` 检查和 `irq_matches_rx_state` 断言，说明控制输出错误不会被正常数据通路掩盖。故障库与正常回归库隔离，不会污染正式 UCDB。

原有 TX 最低位翻转 mutation 也重新执行，6 个发送字节全部触发 `SB_TX_MISMATCH`。后续架构优化又补充了 FIFO full 恒低故障；当前三项 mutation 分别覆盖数据、IRQ 控制和 FIFO 控制，但不代表所有故障类型都已经被证明可检出。

## 6. 本地验证结果

- P2 结构检查：11/11 PASS；
- 寄存器模型结构检查：14/14 PASS；
- CDC 结构检查：22/22 PASS；
- P2 关键定向测试：5/5 PASS；
- 非整数时钟比和错相定向测试：3/3 PASS；
- TX 数据 mutation：PASS，已检出；
- IRQ 控制 mutation：PASS，已检出；
- FIFO full 控制 mutation：PASS，已检出；
- 三组完整回归：45/45 PASS，warning、error、fatal 均为 0；
- 合并 45 个 UCDB：功能覆盖 65/65，断言 42/42，cover property 14/14。

详细证据分别保存在 `reports/p2_structural_summary.md`、`reports/config_latency_summary.md`、`reports/mutation_matrix.md` 和 `reports/final_regression/`。

## 7. 结论与边界

P2 完成后，RX 检查不再信任 driver 事务，参考预测和结果比较也有了清楚的职责边界；配置跨域的“写入”和“生效”能够被单独观察和验证。这使验证环境更适合在论文中说明检查独立性，而不只是展示测试数量。

当前结论仍属于 RTL 仿真、结构审计和 mutation 证据。没有商业 CDC/lint 报告，也没有 FPGA 板级结果，因此不能把本轮通过表述成流片级 signoff 或硬件实测完成。
