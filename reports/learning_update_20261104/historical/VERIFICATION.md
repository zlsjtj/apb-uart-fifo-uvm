# 本轮验证记录 — 2026-11-02

## 实际完成

| 范围 | 工具 | 结果 |
| --- | --- | --- |
| 原有免费 FIFO | Icarus 12.0 | 8/8 正常配置通过；2/2 指定故障被检出 |
| 新寄存器块 RTL contract | Icarus 12.0 | 12 笔访问通过；指定数据翻转触发 CONTRACT_DATA |
| 新 APB UVM 示例正常版本 | Verilator 5.054 + Accellera UVM 2020.3.1 | 12 笔 monitor 观测完成，0 UVM_ERROR，0 UVM_FATAL |
| 新 APB UVM 示例故障版本 | 同上，同 seed=1702 | 恰好两次 REGBLOCK_DATA；脚本判 EXPECTED_FAULT_DETECTED |
| 新 uart_learning_baud_test | 同上，seed=1701 | 0 UVM_ERROR，0 UVM_FATAL，配置检查完成 |
| 原 uart_loopback_test | 同上，seed=71 | TX=6、RX=6，0 UVM_ERROR，0 UVM_FATAL |
| 完整源文件语法和展开 | Verilator 5.054 + UVM 2020.3.1 | 主工程与新 APB 示例检查通过 |
| 文档与接线检查 | 本地静态检查 | 173 个本地文档链接有效；默认回归仍20项；shell语法、git diff --check通过 |

Verilator 试跑使用 UVM_NO_DPI。每次都有且只有 NO_DPI_USED、NO_VISIT_CHECK 两条 UVM 库警告，免费示例脚本明确检查这两个 ID 及计数。原有 Questa 流程的零 warning 门槛未改变。

## 运行方式

```bash
bash scripts/run_fifo_smoke.sh
UVM_HOME=/path/to/uvm-core APB_UART_VERILATOR=verilator JOBS=2 SEED=1702 bash scripts/run_apb_regblock_verilator.sh
```

UART 两项试跑的完整构建/运行命令在源码 docs/verilator_feasibility.md。新 APB 免费脚本最终按正常、故障顺序构建并实际运行；编译生成的 C++ 使用 -O0 以降低构建开销。

## 范围和未完成项

- 尚未在本环境实跑新 Questa PowerShell runner，也没有重跑旧 ModelSim 10.4 的全套 UVM/覆盖率验收。
- 本轮没有新 UCDB，也没有扩大历史 69/69 功能 bin、60/60 UVM、13/13 RTL mutation 的声明。
- 完整 UART 的 tx_lsb 故障构建曾在并行构建时触发 C++ 编译进程内存限制，未完成该项故障仿真。该工具失败没有计作检出。最终交付的独立 APB 正常/故障路线已完成实际对照。
- 没有推送远程 GitHub、发布 Release、创建外部 Issue 或发布宣传内容。提交与 PR 可由具备该仓库权限的 Codex 按 CODEX_NEXT.md 完成。

## 本包日志

- fifo-smoke-summary.txt：原有 FIFO 运行摘要。
- apb-uvm-baseline.log、apb-uvm-fault.log：最终免费 APB 对照运行。
- uart-learning.log、uart-loopback.log：主 UART 工程两项有限试跑。

日志中保留实际工具信息和临时工作路径，不包含许可证或账号凭据。
