# 寄存器模型说明

## 1. 为什么要统一寄存器定义

原来的寄存器地址分别写在 RTL、SVA 和 UVM sequence 中。代码不多时这样做看不出问题，但只要地址表发生调整，就可能出现 DUT 已修改、测试仍使用旧地址的情况。更麻烦的是，测试有时仍能跑完，只是检查目标已经偏了。

本轮新增 `rtl/apb_uart_reg_pkg.sv`，集中保存五个寄存器的地址、CTRL 和 STATUS 位号、CTRL 掩码以及复位值。RTL、断言、coverage、sequence 和 RAL 都从这个 package 取值。sequence 中保留的短名称只是可读性别名，不再保存数值副本。

## 2. RAL 的范围

`tb/uvm/uart_reg_model.svh` 建立了一套轻量 UVM RAL。它没有追求自动生成或复杂 field coverage，而是先把当前设计真正需要的五个寄存器描述清楚：

| 寄存器 | 访问属性 | 复位值 | 说明 |
| --- | --- | --- | --- |
| CTRL | RW | 0 | 只有低 3 位有效，写入值会按掩码处理 |
| STATUS | RO | 低 6 位为 0x5 | bit6 CFG_BUSY；bit7 TX_BUSY；复位恢复完成且无在途发送时为 0x5 |
| BAUD | RW | 16 | 写 0 时硬件实际保存 1 |
| TXDATA | WO | 无稳定复位镜像 | 写操作可能推进 TX FIFO |
| RXDATA | RO | 无稳定复位镜像 | 读操作可能弹出 RX FIFO |

TXDATA 和 RXDATA 带有 FIFO 副作用，因此不把它们当成普通存储寄存器做 reset mirror。复位镜像检查集中在 CTRL、STATUS 和 BAUD。

## 3. adapter 和 predictor 的连接

`uart_apb_reg_adapter` 负责在 `uvm_reg_bus_op` 与现有 `apb_item` 之间转换。前门访问继续使用原有 APB sequencer 和 driver，不另外搭一套总线组件。

环境中关闭 RAL 的自动预测，并把 `uvm_reg_predictor#(apb_item)` 接到 APB monitor。这样无论访问来自 RAL sequence，还是来自原有的普通 APB sequence，镜像都以 monitor 实际看到的事务为准。adapter 在预测阶段还处理两条 DUT 语义：CTRL 只保留低 3 位，BAUD 写 0 后镜像更新为 1。

数据流可以概括为：

```text
RAL frontdoor -> APB sequencer -> APB driver -> DUT
                                      |
APB monitor -> register predictor -> RAL mirror
```

## 4. reset mirror 的处理

外部复位由独立 reset monitor 观察，并统一通知 predictor、scoreboard、coverage 和 RAL。只有 APB reset 才重置寄存器镜像；UART-only reset 保留 APB 配置。测试不手工调用 regmodel.reset() 来修正镜像。

STATUS 拆为低 6 位状态、CFG_BUSY、TX_BUSY 三个字段。两个 busy 字段为 volatile，关闭固定镜像比较；对应的公开状态检查不能省略。CFG_BUSY 由配置轮询检查；TX_BUSY 由发送完成测试检查写入后置位、完整停止位结束前保持和最终清零。

正常配置流程为：停止提交 TX 数据并保证外部 RX 无在途帧，等待 TX_BUSY=0 且 CFG_BUSY=0，再写 CTRL/BAUD，最后等待 CFG_BUSY=0。普通 APB sequence 已封装 TX 排空及配置轮询；故障注入、邮箱突发和显式中止使用原始访问接口，不暗中套用正常流程。

## 5. 历史验证结果（2026-09-04，不能代替本轮结果）

- 寄存器模型结构检查：16/16 PASS；
- RAL 定向测试：前门读写、访问属性、被动预测、BAUD=0 归一化和 reset mirror 全部通过；
- 三组 seed 完整回归：51/51 PASS，warning、error、fatal 均为 0；
- 51 个 UCDB 合并后，功能覆盖 65/65、断言 51/51、cover property 15/15；
- TX LSB mutation 仍被 scoreboard 检出，6 个发送字节全部产生 `SB_TX_MISMATCH`。

结构检查报告在 `reports/register_model_structural_summary.md`，完整回归明细在 `reports/final_regression/final_regression_summary.md`。
