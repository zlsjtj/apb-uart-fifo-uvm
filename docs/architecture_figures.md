# 当前架构图

图示对应固定 8N1 验证模型，不代表完整工业 UART 或板级实现。

## 数据通路

```mermaid
flowchart LR
  APB[APB 主机] <--> REG[寄存器 pclk]
  REG --> TXF[TX 异步 FIFO]
  TXF --> TX[UART TX uart_clk]
  TX --> TXPIN[TX 引脚]
  RXPIN[RX 引脚] --> RX[简化 UART RX]
  RX --> RXF[RX 异步 FIFO]
  RXF --> REG
  REG --> MAIL[CTRL/BAUD 配置邮箱]
  MAIL --> CORE[UART 配置与波特率]
  CORE --> TX
  CORE --> RX
  TX --> DONE[完整停止位后完成计数]
  DONE --> GRAY[Gray 两级同步]
  GRAY --> BUSY[与 APB 接收计数比较]
  BUSY --> REG
```

TX_EMPTY 只说明 FIFO 已空。TX_BUSY 还包括在途发送；disable 中止和 reset 丢弃不能当作成功送达。

## UVM 环境

```mermaid
flowchart LR
  SEQ[sequence] --> AGENT[APB/UART agent]
  AGENT --> DUT[DUT 公开接口]
  DUT --> AM[APB monitor]
  DUT --> TM[TX 引脚 monitor]
  DUT --> RM[RX 引脚 monitor]
  AM --> PRED[predictor]
  TM --> PRED
  RM --> PRED
  PRED --> SB[scoreboard]
  AM --> SB
  TM --> SB
  AM --> RAL[RAL predictor]
  AM --> COV[coverage]
  TM --> COV
  RESET[统一 reset monitor] --> PRED
  RESET --> SB
  RESET --> RAL
  RESET --> COV
  PROBE[可选内部配置探针] --> CHECK[env 白盒 checker]
```

RAL 只接 APB 事务，RX 引脚事务先进入 predictor，再与 APB 读回的数据比较。探针不生成串行期望；无探针模式移除相关类和接口实例。

## 配置 CDC 与复位

```mermaid
flowchart TD
  REQ[APB 请求] --> HOLD[保持整个配置载荷]
  HOLD --> SYNC[req 两级同步]
  SYNC --> APPLY[UART 域应用配置]
  APPLY --> ACK[ack 两级同步返回]
  ACK --> READY[CFG_BUSY 清零]
  EXT[外部复位] --> ASSERT[异步置位]
  ASSERT --> PCLK[pclk 同步释放]
  ASSERT --> UCLK[uart_clk 同步释放]
  PCLK --> EPOCH[清空共享 FIFO 和模型 epoch]
  UCLK --> EPOCH
  EPOCH --> REPLAY[UART 单域复位后重放配置]
```

配置握手不自动证明外部 RX 空闲。正常改配置需停止提交 TX、等待 TX_BUSY/CFG_BUSY，并由通信协议保证没有在途 RX 帧。

源码入口为 rtl/apb_uart.sv、tb/uvm/uart_env.svh。环境预检查、快照内回归和证据门禁由 run_acceptance.ps1 组织，选定 PASS 运行后由 export_acceptance.ps1 校验发布。
