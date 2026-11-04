# Verilator: tested examples / 已验证的示例范围

The 2026-11-02 learning update was checked on Ubuntu 24.04 with
Verilator **5.054** and the official Accellera **UVM 2020.3.1** tag.
The UVM library is an external dependency; it is not bundled in this repository.

本轮为免费学习路线做了实际构建和运行。推荐从
[独立 APB 示例](../examples/apb-regblock/README.md)开始：它有成对运行脚本，
并且检查正常结果、指定故障及两条已声明的 UVM 库警告。

## UART pilot / UART 小范围试跑

The complete UART source filelist compiled and elaborated successfully. These
two selected simulations completed with zero UVM errors and zero UVM fatals:

| Test | Seed | Observed result |
| --- | --- | --- |
| `uart_learning_baud_test` | 1701 | BAUD normalization/readback sequence completed; zero register-check errors |
| `uart_loopback_test` | 71 | Scoreboard checked TX=6 and RX=6; zero comparison errors |

Both runs emitted exactly the UVM library warnings `NO_DPI_USED` and
`NO_VISIT_CHECK`, caused by `UVM_NO_DPI`. The register test has no serial traffic;
its TX/RX scoreboard counts are therefore zero. The original Questa runner's
zero-warning acceptance rule remains unchanged.

两项结果只覆盖上表测试。完整的 20 项回归、全部故障注入和覆盖率流程仍使用既有
Questa 路线；本轮没有生成或迁移 UCDB。UART 的 `tx_lsb` 故障构建曾遇到本次执行
环境的 C++ 编译内存限制，未完成该故障仿真，也没有把工具失败计作检出。

## Reproduce the pilot / 复现小范围试跑

Use a C++ compiler with coroutine support, Make, Perl and Verilator 5.054.
Set `UVM_HOME` to the official `uvm-core` checkout at tag `2020.3.1`.
Run from the repository root:

```bash
verilator --binary --timing --assert -j 2 -Wno-fatal -Wno-TIMESCALEMOD \
  +define+UVM_NO_DPI "+incdir+$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" \
  -f filelist.f --top-module tb_apb_uart --Mdir work_verilator_uart

work_verilator_uart/Vtb_apb_uart +UVM_TESTNAME=uart_learning_baud_test +verilator+seed+1701
work_verilator_uart/Vtb_apb_uart +UVM_TESTNAME=uart_loopback_test +verilator+seed+71
```

This is a reproducible pilot command, not an automated replacement for
`run_questa.ps1`. Inspect the UVM summary and the expected checker messages;
the simulator's exit code alone does not establish success. `-Wno-fatal`
retains compiler diagnostics while allowing the existing UVM macro width
warnings; it does not suppress UVM runtime failures.

后续优先把同测试、同 seed 的 UART 正常/故障对照跑完，再评估其他测试。
只有完成对应验证后，才扩大公开支持范围和 CI 声明。

## References / 参考

- [Verilator release history](https://verilator.org/guide/latest/changes.html)
- [Verilator UVM tracking](https://github.com/verilator/verilator/issues/1538)
- [Accellera UVM 2020.3.1](https://github.com/accellera-official/uvm-core/tree/2020.3.1)
- [Shared APB example](../examples/apb-regblock/README.md)
- [Existing interface and result scope](interface_and_scope.md)
