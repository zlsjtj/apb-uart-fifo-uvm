# APB agent reuse / APB agent 复用示例

这个第二 DUT 是三个寄存器的可综合 APB 外设，演示从 UART 项目直接复用 agent：不需要 UART RTL、串口 agent、UART predictor、RAL 或 coverage/UCDB 流程。
This second DUT is a synthesizable three-register peripheral. It directly reuses the APB agent without the UART verification environment.

从仓库根目录，在已配置 UVM 的 Questa + PowerShell 环境运行：
Run from the repository root with Questa's UVM installation available. The script reuses `APB_UART_QUESTA_BIN` / `toolchain.local.psd1` configuration; Vivado is not required:

```powershell
pwsh -File scripts/run_apb_regblock.ps1
pwsh -File scripts/run_apb_regblock.ps1 -InjectFault
```

正常运行仅在 12 笔 monitor 观察到的完成传输、零 UVM error/fatal/warning 时返回 0。故障运行启用 `REGBLOCK_INJECT_FAULT`，令 scratch 写入值 bit 0 翻转；必须恰好观察到两次 `REGBLOCK_DATA` 错误、总 UVM_ERROR=2、零 fatal/warning 且完整结束，才输出 `EXPECTED_FAULT_DETECTED` 并返回 0。编译失败、超时或其他错误不属于预期失败。脚本异常返回非零；默认固定 Seed=1702（可用 `-Seed` 修改）；baseline 与 fault 分别保存在 `logs/apb-regblock/baseline_1702/` 和 `logs/apb-regblock/fault_1702/`，同一模式/seed 重跑会更新该目录日志。该成功状态说明故障被发现，不代表故障 DUT 通过功能验证。
Normal mode requires 12 observed transfers and zero UVM errors, fatals and warnings. Fault mode succeeds only when the two specific scratch readback mismatches are detected and the test completes. Compilation errors and timeouts fail both modes. The fixed default seed is 1702; use `-Seed` to override. Baseline and fault logs use separate mode/seed directories. This example does not create coverage or UCDB evidence.

## Register contract / 寄存器约定

| Byte address | Register | Reset | Behavior |
| --- | --- | --- | --- |
| `0x00` | ID | `0x52454731` | read-only; writes return PSLVERR |
| `0x04` | SCRATCH | `0x12345678` | full 32-bit read/write |
| `0x08` | CONTROL | `0` | bits [1:0] writable; other bits read zero |
| all others | unmapped | — | reads and writes return PSLVERR; reads return zero |

`PREADY=1`，没有等待状态。错误访问不修改寄存器。检查器用独立模型计算期望值，经 `agent.mon.ap` 接收接口观察结果；sequence 只发请求，不用 driver 返回值代替检查。12 笔传输覆盖初始复位默认值、合法写读、保留位、只读写错误、非法地址读写错误，以及后续内容保持。它不验证复位中断事务、随机压力、全部 APB 协议性质或完整功能覆盖率。
The independent checker models the register contract and compares monitor observations. The directed sequence covers initial reset values, legal accesses, reserved bits, read-only and unmapped access errors, and retained state. It is a reuse demonstration, not a complete APB protocol VIP or coverage signoff.

## What is reused / 哪些文件直接复用

- `tb/interfaces/apb_if.sv`: shared physical interface and clocking blocks.
- `tb/uvm/apb_agent_pkg.sv`: sole owner of `apb_item`, `apb_sequencer`, `apb_driver`, `apb_monitor`, `apb_agent`; the five `.svh` files are included once here.
- UART imports and re-exports this package through `uart_pkg`; existing `import uart_pkg::*` clients retain access. Compile `apb_if`, then `apb_agent_pkg`, then the consuming package. Do not include these APB class files again in your own package.

当前支持固定 **8-bit byte address / 32-bit data**，无 PSTRB/PPROT，单个 active agent。driver 在首次复位释放后等待 3 个上升沿（保留 UART 复位流水线的兼容时间），无事务 ready 超时、无中途复位恢复；本例 top 提供整次仿真 watchdog。monitor 只在 reset 已释放且 PSEL/PENABLE/PREADY 均有效时广播完成事务。初始复位由 top 驱动，checker 模型初始化为约定默认值。
Current shared-agent scope: fixed 8-bit addresses, 32-bit data, no strobes/protection, one active agent. The driver retains three rising edges of settling after initial reset release. It has no per-transfer ready timeout or mid-transfer reset recovery; the example top supplies an overall watchdog.

替换自己的 DUT：修改 `regblock.sv` 或 top 实例端口连接，更新 `regblock_checker` 的寄存器模型和 sequence，修改期望传输计数及 filelist；保持 APB interface/agent 不变。若地址或数据宽度不同，必须协调修改公共 interface/item/driver/monitor，不能仅改变 DUT 参数。
For a different DUT, change the RTL/top binding, register oracle, stimulus, expected transaction count and filelist. Preserve the shared interface and agent when your bus matches this subset.

本轮已用下方 Verilator 配置执行 UVM 示例。2026-11-04 的 ModelSim 10.4 复验中，正常／故障版本均编译通过，仿真因许可证 checkout 失败而未执行；详见[本机复验记录](../../docs/learning_update_validation.md)。
The UVM example was exercised with the Verilator configuration below. Both variants compiled with ModelSim 10.4 on 2026-11-04; simulation was blocked by license checkout. See the linked local check record.

可选的轻量 RTL 检查 / optional RTL-only contract check (Icarus):

```sh
iverilog -g2012 -s tb_regblock_contract -o /tmp/regblock-contract examples/apb-regblock/regblock.sv examples/apb-regblock/tb_regblock_contract.sv
vvp /tmp/regblock-contract
```

This checks the DUT contract only, not UVM compilation or agent integration. Adding `-DREGBLOCK_INJECT_FAULT` must fail at `CONTRACT_DATA` on the scratch read; a compile error is not detection evidence.

## Verilator route / 无商业许可的独立示例路线

第二种路线使用 Verilator、Accellera UVM 和 `UVM_NO_DPI`，只运行这个独立 regblock 示例。需要 Bash、Python 3、GNU coreutils 的 `timeout`、C++ 编译器、make 及 Verilator。实际集成验证版本为 **Verilator 5.054 + Accellera UVM 2020.3.1**；其它版本可能存在 UVM 支持差异，不能由本结果推断兼容性。
This independent route needs no commercial simulator license. Prerequisites are Bash, Python 3, GNU coreutils `timeout`, a C++ compiler, make and Verilator. The integration tested uses Verilator 5.054 and Accellera UVM 2020.3.1.

从官方仓库获取 UVM（此版本的实际 tag 是 `2020.3.1`）：
Fetch UVM from its official repository:

```sh
git clone --depth 1 --branch 2020.3.1 https://github.com/accellera-official/uvm-core.git /tmp/uvm-core
export UVM_HOME=/tmp/uvm-core
# Optional: a single executable path, not a command with arguments.
export APB_UART_VERILATOR=verilator
JOBS=2 SEED=1702 bash scripts/run_apb_regblock_verilator.sh
```

`UVM_HOME` 必须包含 `src/uvm_pkg.sv`；`APB_UART_VERILATOR` 默认 `verilator`，`JOBS` 默认 2，`SEED` 默认 1702。脚本以同一个固定 seed 成对构建、运行 baseline 和 fault，分别使用临时 build 目录，退出后清理生成的 C++/binary。完整编译和运行日志保留在 `logs/apb-regblock/verilator_baseline_1702/` 和 `logs/apb-regblock/verilator_fault_1702/`。同一模式/seed 的重跑更新对应日志。脚本打印 Verilator 版本、UVM 路径及日志根目录；每次编译的进程超时默认 300 秒、每次运行默认 30 秒，可分别通过 `BUILD_TIMEOUT_SECONDS` 和 `RUN_TIMEOUT_SECONDS` 设置正整数秒数。
The script builds both baseline and fault separately and uses the same `+verilator+seed+1702` seed by default. Full compile/run logs remain in separate mode/seed directories; temporary build products are removed on exit.

`UVM_NO_DPI` 禁用 UVM 的 DPI 功能。此组合的 UVM 库会明确报告 `NO_DPI_USED` 和 `NO_VISIT_CHECK`：前者说明 DPI 被禁用，后者说明相应的访问检查不可用。这条路线仅允许这两个 warning 各一次，同时要求 warning 总数恰为 2；其它 warning 仍视为失败。Questa 路线仍要求零 warning，没有放宽。
With `UVM_NO_DPI`, the UVM library reports `NO_DPI_USED` (DPI disabled) and `NO_VISIT_CHECK` (the corresponding visit check is unavailable). Only one occurrence of each is permitted, with exactly two warnings in total. Other warnings fail this route; the Questa route retains its zero-warning requirement.

Verilator 编译使用 `-Wno-fatal`，使现有 UVM 宏展开产生的编译 warning 不直接终止构建；完整编译日志保留供审阅。运行门槛独立检查：12 笔 monitor 摘要、baseline ERROR=0、fault ERROR=2 且两条都是 `REGBLOCK_DATA`、FATAL=0，以及上述精确 warning 清单。编译失败、仿真异常退出或 watchdog 超时均失败。成对检查均符合预期才返回 0。
Compile warnings remain visible in the complete build log; `-Wno-fatal` permits known macro-related compiler warnings. Runtime acceptance requires all 12 observed transfers, exact UVM counts and diagnostic IDs. GNU timeout also bounds each compiler and simulator process (defaults: 300 seconds to build, 30 seconds to run; override with `BUILD_TIMEOUT_SECONDS` and `RUN_TIMEOUT_SECONDS`). A failed compilation, abnormal simulation exit or timeout cannot count as fault detection.

The free teaching runner compiles generated C++ with `-O0` to reduce build cost. Its logs are functional checks, not simulator speed measurements. On a memory-limited machine use `JOBS=1`.
免费教学脚本用 `-O0` 编译生成的 C++，降低构建开销；结果用于功能检查。内存较小时使用 `JOBS=1`。
