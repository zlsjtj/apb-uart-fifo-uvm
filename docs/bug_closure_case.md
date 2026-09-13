# APB 晚响应缺陷与检查器对照

## 发现过程

2026-09-05 复查代码时发现：PREADY 固定为 1，但 PRDATA 和 PSLVERR 到传输完成沿之后才由非阻塞赋值更新。driver 和 monitor 又都延后 2 ns 读取，所以正常回归一直看不到这段空窗。

独立小测试没有使用原来的 APB BFM，在真正的完成沿直接采样，得到：

| 操作 | 完成沿读到 | 延后 2 ns 读到 | 规格要求 |
| --- | --- | --- | --- |
| 复位后读 BAUD | 0 | 16 | 完成沿应为 16 |
| 非法地址读取 | PSLVERR=0 | PSLVERR=1 | 完成沿应报错 |

这说明问题不只是 DUT 的时序写法，也包括检查器重复了 DUT 的错误假设。历史的 51/51 PASS 不能证明 APB 协议已经正确。

## 修复

寄存器层改成组合读数据和组合错误响应，保证完成沿前有效；配置寄存器写入、TX push 和 RX pop 仍在握手沿更新。driver/monitor 改用 clocking block 的 input #1step 采样，错误响应 SVA 也改为同拍检查。

独立的 tb/unit/apb_contract_tb.sv 保留在仓库，连续访问时 PSEL 不插空闲周期，检查默认值、读写、非法地址、受限访问、loopback 出队和 FIFO 回绕。它不调用 UVM 的 APB driver，因此能对 driver 之外的接口行为作第二次核对。

## 如何防止同类问题回来

UART_MUTATE_APB_LATE_RESPONSE 会让 APB 响应重新晚一拍。campaign 对同一个 uart_reg_test 和相同 seed 先运行正确版本，再运行故障版本：

- 正确版本必须完整结束，无 warning/error/fatal。
- 故障版本必须命中实际错误记录里的 REG_DEFAULT、REG_RW、SEQ_EXP_ERR 或对应 APB SVA。
- 日志只有检测器名字、但错误来自别处，不算检出。
- 许可证、加载失败和超时不算检出。

命令：

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds apb_late'
```

完整清单在 config/mutation_plan.psd1，还覆盖 TX/RX 数据、FIFO 状态、IRQ、波特率、配置握手、帧错误和同步复位。每项使用独立故障库，baseline 与 mutant 的日志和匹配错误记录写入 mutation_campaign.json。

## 论文里可以怎样说明

本案例的价值是“通过独立接口采样发现 DUT 与 BFM 的共同盲区，再用故障对照验证修复后的检查器”，不是把多跑一次测试当成创新。mutation 的检出率仅针对清单声明的故障模型，不外推为全部 RTL 错误的覆盖率。
