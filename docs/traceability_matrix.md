# 需求—验证追溯矩阵

本文档把 `requirements_and_scope.md` 中的 RQ-01 到 RQ-10 落到具体测试、检查机制和覆盖率上。它不是一次写完后就不动的表：每新增一个用例、断言或覆盖点，都应在这里更新状态和证据路径。

状态说明：

- **已完成**：已有测试和检查机制，正式回归通过，并能在覆盖率或报告中找到证据；
- **部分完成**：已有基础用例，但边界、检查独立性或覆盖率仍不足；
- **未完成**：尚无对应测试，或没有足以支撑结论的证据。

当前的 13/13 回归结果可以作为起点，但不单独作为“已完成”的判据。

## 1. 总表

| RQ | 需求 | 现有测试或序列 | 现有检查 | 现有覆盖/证据 | 当前状态 | 主要缺口与下一步 |
| --- | --- | --- | --- | --- | --- | --- |
| RQ-01 | CTRL、BAUD 的复位值、读写和非法访问正确 | `uart_reg_test` / `uart_reg_seq` | sequence 检查读回值和 `pslverr`；`apb_uart_sva` 检查 APB 基本时序与非法地址 | 地址、读写和错误 coverpoint；现有回归记录 | 部分完成 | 补 BAUD=0 归一化、错误访问无副作用、STATUS 位读写保护的完整检查；明确 APB 读数据的时序语义 |
| RQ-02 | APB 写 TXDATA 后按顺序从 TX 串行输出 | `uart_loopback_test`、`uart_random_test` | TX monitor + scoreboard 比较 APB 写入和 TX 帧数据 | UART 数据 coverpoint；loopback sample log 中有 TX=6 | 部分完成 | 增加长突发、FIFO 边界前后的顺序检查；独立检查 start/data/stop 位宽，不只按 DUT 的 `bit_tick` 解码 |
| RQ-03 | 外部 RX 与 loopback 数据能按顺序从 RXDATA 读回 | `uart_external_rx_test`、`uart_loopback_test` | sequence 和 scoreboard 检查 RXDATA | UART 数据 coverpoint | 部分完成 | RX 期望目前主要来自 driver 发出的激励；补独立 RX 观察或参考模型，并覆盖连续帧、不同间隔和错误帧后的恢复 |
| RQ-04 | TX/RX FIFO 的满、空、溢出、下溢和恢复行为明确 | `uart_fifo_full_test`、`uart_rx_fifo_full_test`、`uart_bad_access_test` | scoreboard 检查 RX 顺序与满时丢弃；SVA 区分 APB 请求与 `tx_push`/`rx_pop`，检查满写、空读和只读写拒绝时无 FIFO 副作用 | RX 空/部分/满状态、满/清除转换及四类拒绝访问 cover property 均已覆盖 | 已完成 | 保留满、空和恢复用例；若修改 FIFO 接口语义，需要同步更新请求与接受操作断言 |
| RQ-05 | IRQ、frame error、STATUS 位可验证 | `uart_irq_test`、`uart_frame_error_test` | sequence 检查 STATUS、IRQ、坏帧拒收和正常帧恢复；SVA 检查 IRQ 关系及坏帧不写 RX FIFO | IRQ 四种状态和转换、frame error 检测和恢复均已覆盖 | 已完成 | 保留回归和覆盖率证据；后续若修改 RX/STATUS 语义，需要同步重跑这两个用例 |
| RQ-06 | BAUD 边界、常用分频和配置更新行为可解释 | `uart_baud_loopback_test`、`uart_baud_timing_test` | 不依赖 `bit_tick`，从 `tx_o` 边沿测量 9 个连续帧位宽 | BAUD=0/1/4/8 与测量通过交叉覆盖 100%；40 ns、26 ns 两种 UART 时钟均通过 | 已完成 | 当前约定只在帧间更新 BAUD；若以后支持帧内动态更新，需要重新定义并补测 |
| RQ-07 | CDC、时钟比例和独立复位下稳定 | `uart_reset_cdc_test`、CDC 结构检查、三组正式回归 | 双复位/APB-only/UART-only 恢复；异步 FIFO Gray 指针；CTRL/BAUD 请求应答邮箱；RX full、frame error 两级同步；各目标域异步断言、同步释放 | `reset_cg` 100%；CDC 结构规则 22/22；8 条复位断言无失败；39/39 PASS | 部分完成 | 本科范围内的结构审计和动态压力验证已完成；仍缺商业 CDC/lint 与 reset-domain signoff，不能据此作流片级结论 |
| RQ-08 | UVM 环境能将遗漏、顺序错误和错误响应判为失败 | scoreboard、SVA 与 `run_mutation_check.ps1` | TX、RX 队列比较；残留期望数据报 error；APB/FIFO 断言；TX 数据最低位翻转故障注入 | 故障版本的 6 个发送字节全部触发 `SB_TX_MISMATCH`；正常回归 13/13 PASS | 已完成 | 故障注入使用独立仿真库；证据和适用边界见 `bug_closure_case.md` |
| RQ-09 | 验证范围有量化结论 | `run_questa.ps1` 保存单例 UCDB，`merge_coverage.ps1` 按最新回归表合并 | 功能、代码、断言及 HTML/text 报告均已生成 | 功能覆盖率 100%，断言 40/40、cover directive 13/13 且无失败；核心 RTL statement 95% 以上 | 已完成 | 保留 `coverage_closure.md` 中的 scope 和 waiver；RTL 或 coverage model 修改后必须重跑完整闭环 |
| RQ-10 | 最终结果可复现 | `scripts/run_final_regression.ps1`、39 次回归摘要、源码哈希和 39-UCDB 合并报告 | 脚本统计 error/fatal，记录时钟配置、seed、工具/UVM 版本、工作区状态和 SHA-256 | 2026-09-03 的 39/39 PASS；功能 65/65、断言 40/40、cover property 13/13 | 已完成 | 最终 commit 以源码清单中的 SHA-256 与本次已测文件逐项比对，确保提交内容就是被测版本 |

## 2. 现有文件与 RQ 的对应关系

| 文件 | 当前作用 | 主要对应 RQ | 后续改动方向 |
| --- | --- | --- | --- |
| `rtl/apb_uart.sv`、`rtl/reset_sync.sv` | APB-UART DUT、FIFO 连接、BAUD/控制跨域与复位路径 | RQ-01、04、05、06、07 | CTRL/BAUD 使用请求应答邮箱，RX full/frame error 通过两级同步，各目标域复位异步断言、同步释放 |
| `rtl/async_fifo.sv` | 双时钟异步 FIFO | RQ-04、07 | Gray 指针同步器已标注 `ASYNC_REG`；仍需商业工具完成库和约束层面的检查 |
| `rtl/async_fifo_sva.sv` | FIFO 基础断言 | RQ-04、08 | 区分请求与接受操作，补拒绝操作无副作用的断言和 cover property |
| `rtl/apb_uart_sva.sv` | APB 及 IRQ 基础断言 | RQ-01、05、08 | 补 IRQ、STATUS、错误响应和 BAUD 行为的断言 |
| `tb/uvm/uart_scoreboard.svh` | TX/RX 顺序检查 | RQ-02、03、04、08 | 将未消费 RX 数据设为失败，扩展寄存器/FIFO/IRQ 参考检查 |
| `tb/uvm/uart_coverage.svh` | APB/UART 功能覆盖 | RQ-01、02、03、04、09 | 加入 IRQ、frame error、FIFO 状态、复位、BAUD 和关键交叉覆盖 |
| `tb/uvm/uart_sequences.svh` | 现有定向与随机序列 | RQ-01 至 RQ-06 | 增加 IRQ、错误帧、RX 满、reset、BAUD timing 和压力序列 |
| `tb/top/tb_apb_uart.sv` | 时钟、复位和 DUT 顶层 | RQ-07 | 支持时钟周期、相位与 reset 策略的参数化 |
| `scripts/run_questa.ps1`、`scripts/merge_coverage.ps1`、`scripts/run_final_regression.ps1`、`scripts/run_cdc_structural_check.ps1` | 编译、单测、UCDB 保存、精确合并、多 seed 回归、CDC 结构审计和证据清单生成 | RQ-07、09、10 | 提交最终版本后重新冻结一次干净工作区的 manifest |

## 3. 下一轮实施清单

下面的编号可直接用于提交信息、调试记录和后续论文表格。

| 任务 | 对应 RQ | 完成条件 |
| --- | --- | --- |
| T-01（已完成）：补 IRQ 测试 | RQ-05 | 已覆盖 `irq_en=0/1`、RX 数据到达后的拉高、读空后的撤销，并检查 STATUS |
| T-02（已完成）：补 frame error 测试 | RQ-05 | UART driver 已支持错误停止位；测试覆盖错误状态、坏帧拒收、IRQ 保持低和正常帧恢复 |
| T-03（已完成）：补 RX FIFO 满与恢复测试 | RQ-04 | 已验证 16 字节写满、第 17 帧拒收、顺序读空、状态/IRQ 清除和恢复后重新接收 |
| T-04（已完成）：补 reset/CDC 压力测试 | RQ-07 | 已覆盖传输中双复位、独立 reset、两组非整数时钟比和不同初相位，并验证复位后恢复 |
| T-05（已完成）：补 BAUD 时序检查 | RQ-06 | 已独立验证 BAUD=0/1/4/8 下 TX 帧位宽，并在两种 UART 时钟周期下通过 |
| T-06（已完成）：加强 scoreboard 和 SVA | RQ-04、08 | 已检查 TX 满写/禁用写、RX 空读/只读写、非法地址无 FIFO 副作用；寄存器可见状态保持不变；TX 位翻转 mutation 被 scoreboard 检出 |
| T-07（已完成）：补覆盖率闭环脚本 | RQ-09 | 已按最新回归表合并 13 个 UCDB，输出文本/HTML 报告，并完成未覆盖项和 waiver 说明 |
| T-08（已完成）：冻结正式回归证据 | RQ-10 | 3 组 seed、39/39 PASS；报告包含版本、工具、命令、seed、39-UCDB 合并覆盖率、工作区状态和源码 SHA-256 |
| T-09（已完成）：CDC 结构审计与修正 | RQ-07 | CTRL/BAUD 原子配置邮箱、RX full/frame error 同步、FIFO/邮箱同步器标注；22/22 结构规则通过，39/39 回归通过 |
| T-10（本轮完成）：P0 复位释放收口 | RQ-07、09、10 | APB、UART 与 FIFO 两侧均采用异步断言、两级同步释放；三组错相/异比定向测试通过，新增复位断言与 cover 全部命中 |

## 4. 更新规则

1. 新增测试时，先在本表找到对应 RQ；若没有对应 RQ，应先判断它是否属于范围扩展。
2. 用例通过并不自动把状态改为“已完成”；需要同时确认检查机制和覆盖率证据存在。
3. 对不可达代码或不支持的 UART 特性，写明原因并建立 waiver，不用伪造覆盖率。
4. 最终回归完成后，将总表中的“现有覆盖/证据”替换为具体报告路径和数值。

这张表的作用是控制范围：每次准备新增功能前，先问它对应哪条 RQ、能补哪一类证据。如果两者都回答不上来，就不应优先做它。
