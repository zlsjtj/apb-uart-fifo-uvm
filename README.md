# APB UART FIFO UVM Lab

This repository is a small SystemVerilog/UVM verification lab for an
APB-controlled UART model with asynchronous FIFO buffers.

The goal is to show a complete but still understandable verification flow:
RTL, interfaces, UVM agents, scoreboard, coverage, directed/random tests,
regression scripts, and a short set of notes about what was checked.

## Directory Layout

```text
rtl/                DUT and SVA
config/             Declarative regression plan and RTL coverage policy
tb/interfaces/      APB and UART interfaces
tb/uvm/             UVM items, agents, env, predictor, scoreboard, coverage
tb/uvm/sequences/   Feature-oriented APB/UART sequences
tb/uvm/tests/       Feature-oriented UVM tests
tb/top/             Simulation top
scripts/            Local regression entry points
reports/            Regression summary and sample logs
docs/               Verification and coverage notes
```

## Register Map

寄存器地址、复位值和位定义统一放在 `rtl/apb_uart_reg_pkg.sv`。RTL、SVA、
UVM sequence 和寄存器模型都引用同一份定义，避免后续修改时出现地址不一致。

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | CTRL | bit0 enable, bit1 loopback, bit2 irq_en |
| `0x04` | STATUS | bits0..5 FIFO/error/IRQ; bit6 CFG_BUSY; bit7 TX_BUSY |
| `0x08` | BAUD | Read/write configuration register |
| `0x0c` | TXDATA | Write TX FIFO |
| `0x10` | RXDATA | Read RX FIFO |

## Model Scope

This is a verification practice DUT, not a production UART IP.

- `BAUD` controls a simplified UART bit tick in the `uart_clk` domain.
- UART TX/RX still use a simple tick-based serial model. There is no 16x
  oversampling, parity, or configurable stop-bit support.
- APB uses a zero-wait-state `pready=1` response.
- Read data and PSLVERR are valid before the completion edge. Both APB BFMs
  sample with clocking-block input #1step, not a post-edge delay.
- Before normal CTRL/BAUD writes, stop adding TX bytes and poll both TX_BUSY
  and CFG_BUSY to zero. After writing, poll CFG_BUSY again before new traffic.
  The external peer must also keep RX idle across the configuration change.
  TX_EMPTY means FIFO empty; TX_BUSY includes queued data and the entire final
  stop bit. CFG_BUSY covers pending/coalesced configuration and reset recovery.
- An explicit mid-frame disable aborts the active byte; reset discards queued
  and active bytes. TX_BUSY clearing after either operation is not proof of
  successful delivery. Queued bytes remain pending on disable until re-enabled
  or reset. Raw recovery accesses are distinct from normal safe configuration.
- External resets assert asynchronously. Each APB/UART/FIFO reset is released
  through a two-stage synchronizer in its destination clock domain.
- UART-only reset preserves CTRL/BAUD but rejects TXDATA/RXDATA accesses while
  the shared FIFO reset is active. Configuration writes are replayed on recovery.
- Functional coverage is implemented in UVM covergroups, but merged UCDB/HTML
  reporting is generated from the current regression summary.

## Run

当前完整验收使用独立源码快照：

```powershell
pwsh -NoProfile -File scripts/run_acceptance.ps1
```

入口在运行开始即写 RUNNING，失败写 FAIL，完成才写 PASS。每轮源码、日志、
UCDB、综合和压力测试分别保存在 reports/acceptance_runs/<run-id>/workspace，
reports/acceptance_summary.json 指向最近一轮。该目录不纳入 Git，但本地保留。
源码身份以 SHA-256 为准；未提交修改不会被误写为“等于基线 commit”。

单独运行协议/参数测试和证据门禁反向测试：

```powershell
pwsh -NoProfile -File scripts/run_contract_tests.ps1
pwsh -NoProfile -File scripts/run_fifo_unit_tests.ps1
pwsh -NoProfile -File scripts/run_parameter_regression.ps1
pwsh -NoProfile -File scripts/test_evidence_gates.ps1
```

先按 [复现与交付说明](docs/reproduction_and_delivery.md) 配置工具。完整验收
包含工具/许可预检查和工作流反向测试，共 12 步。expanded 模式扩展压力与
mutation 种子，每个故障仍要求同测试、同种子的正确基线通过。

当前入口为 [当前架构](docs/current_architecture_and_optimization.md)，图示见
[架构图](docs/architecture_figures.md)。最近尝试以 acceptance_summary.json 为准；
最近成功交付以 [发布入口](reports/published/latest.json) 为准。完整包在本地
deliveries/<runId>，含可搬移校验清单和自动生成的 paper_results.md。

本轮两次完整验收和交付反向检查见 [工程优化结果](docs/engineering_delivery_result.md)。

历史 P0/P1 记录见 docs/p0_p1_finish_result.md；9 月 5 日基线见
docs/p0_p2_contract_closure.md。后文早期示例报告不作为当前结果。

单独选择 FIFO 深度或关闭白盒探针：

```powershell
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_fifo_wrap_test -FifoAddrWidth 1
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_no_probe_test -NoWhitebox
```

NoWhitebox 模式不实例化 uart_probe_if 或集成白盒 SVA；UART agent 本身始终
只使用公开接口。可选配置 monitor/checker 在 env 层连接，不参与数据期望生成。

On Windows with ModelSim/Questa in `PATH`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1
```

Run a smaller subset:

```powershell
pwsh -NoProfile -Command '& ./scripts/run_questa.ps1 -Tests @("uart_reg_test","uart_loopback_test")'
```

Run the reset/CDC test with a non-integer clock ratio and shifted phases:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 `
  -Tests uart_reset_cdc_test -Seed 52 `
  -PclkHalfNs 7 -UartHalfNs 11 -PclkPhaseNs 2 -UartPhaseNs 5
```

Capture a VCD for the loopback path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2 -DumpLoopbackVcd
```

The VCD is written under `reports/` and is ignored by git.

Merge coverage for the exact tests listed in the latest regression summary:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/merge_coverage.ps1
```

Text reports are written under `reports/coverage/`; the generated HTML entry
point is `reports/coverage/html/index.html`.

Run the isolated TX-data mutation check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_mutation_check.ps1
```

This command passes only when the injected bit error is reported by the
scoreboard. It uses `work_mutation` and does not replace the normal simulation
library. See [`docs/bug_closure_case.md`](docs/bug_closure_case.md).

Run the isolated IRQ-control mutation check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_control_mutation_check.ps1
```

This check forces IRQ low in a separate simulation library and passes only
when the IRQ test or assertion reports the injected fault.

Run the declared representative mutation campaign and generate Markdown/JSON results:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_mutation_suite.ps1
```

Run the complete local acceptance flow:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_acceptance.ps1
```

The acceptance flow combines negative gate self-tests, independent APB/parameter
tests, RTL lint, structural and netlist CDC review, OOC synthesis, three-seed
regression, skewed-clock subsets, coverage gates, and baseline-controlled mutations.
The regression list and stress profiles come from
`config/verification_plan.psd1`; RTL coverage thresholds and waivers come from
`config/rtl_coverage_policy.psd1`.

Run the register-model structural audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_reg_model_check.ps1
```

Run the P2 verification-architecture audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_p2_structural_check.ps1
```

Run the three-seed final regression package (test list comes from the plan):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_final_regression.ps1
```

The package is written to `reports/final_regression/` and includes per-seed
summaries, source SHA-256 values, coverage reports, and a reproducibility
manifest. See [`docs/final_regression_evidence.md`](docs/final_regression_evidence.md).

Run the CDC structural audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_cdc_structural_check.ps1
```

The audit checks project CDC structures and writes
`reports/cdc_structural_summary.md`. It does not replace commercial CDC signoff;
see [`docs/cdc_analysis.md`](docs/cdc_analysis.md).

Run zero-warning RTL lint and the structural CDC/RDC audit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_static_checks.ps1
```

Run reproducible Vivado out-of-context synthesis on the generic Artix-7 evidence part:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_vivado_synth.ps1
```

The resulting QoR is a post-synthesis baseline. It is not a placed-and-routed
timing result, a board frequency claim, a bitstream, or commercial CDC signoff.

## Tests

| Test | Main check |
| --- | --- |
| `uart_reg_test` | Reset values, register read/write, illegal access |
| `uart_config_latency_test` | APB configuration-write time versus UART-domain apply time |
| `uart_config_stress_test` | Back-to-back configuration writes, mailbox busy coalescing, APB/UART independent reset recovery |
| `uart_ral_test` | RAL access policy, frontdoor access, passive prediction, reset mirror |
| `uart_loopback_test` | APB TX write, UART loopback, APB RX readback |
| `uart_baud_loopback_test` | Loopback with `BAUD=4` to check bit tick timing |
| `uart_baud_timing_test` | Independent TX bit-width checks for BAUD=0/1/4/8 |
| `uart_irq_test` | IRQ enable/disable, pending RX data, assert and clear behavior |
| `uart_frame_error_test` | Bad stop-bit rejection, frame-error status, and recovery |
| `uart_external_rx_test` | External UART RX frame and APB readback |
| `uart_external_rx_baud_test` | External RX at `BAUD=4` with an independently timed, phase-offset BFM |
| `uart_rx_fifo_full_test` | RX FIFO full, extra-frame drop, drain, and recovery |
| `uart_reset_cdc_test` | Mid-traffic dual reset, independent resets, and recovery |
| `uart_frame_reset_test` | Abort TX/RX frames on reset; reject FIFO accesses during UART-only reset; preserve/replay configuration |
| `uart_fifo_full_test` | TX FIFO full and overflow error path |
| `uart_bad_access_test` | TXDATA read, RXDATA empty/read-only errors, bad address |
| `uart_random_test` | Random data, random gaps, status interleaving |
| `uart_recover_test` | Disable and re-enable recovery path |

Latest complete acceptance: [`reports/acceptance_summary.json`](reports/acceptance_summary.json).
The standalone [`reports/regression_summary.md`](reports/regression_summary.md) may be only a debug subset.

Sample loopback log excerpt:
[`reports/sample_logs/uart_loopback_test_2.log`](reports/sample_logs/uart_loopback_test_2.log)

## Notes

- Coverage notes: [`docs/coverage_summary.md`](docs/coverage_summary.md)
- Coverage closure: [`docs/coverage_closure.md`](docs/coverage_closure.md)
- Debug notes: [`docs/debug_notes.md`](docs/debug_notes.md)
- Mutation case: [`docs/bug_closure_case.md`](docs/bug_closure_case.md)
- Final regression evidence: [`docs/final_regression_evidence.md`](docs/final_regression_evidence.md)
- CDC analysis: [`docs/cdc_analysis.md`](docs/cdc_analysis.md)
- Register model: [`docs/register_model.md`](docs/register_model.md)
- P2 verification architecture: [`docs/p2_verification_architecture.md`](docs/p2_verification_architecture.md)
- Architecture optimization: [`docs/architecture_optimization.md`](docs/architecture_optimization.md)
- Architecture closure and diagrams: [`docs/verification_architecture_closure.md`](docs/verification_architecture_closure.md)
- P0-P4 optimization closure: [`docs/p0_p4_optimization_closure.md`](docs/p0_p4_optimization_closure.md)
- Current architecture and latest optimization: [`docs/current_architecture_and_optimization.md`](docs/current_architecture_and_optimization.md)
