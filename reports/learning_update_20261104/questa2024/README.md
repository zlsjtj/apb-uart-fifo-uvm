# Questa 2024.1 local check - 2026-11-04

This is the initial warning-bearing check. The subsequent
[four independent cold-start checks](../questa_cold/README.md) resolve the
warning blocker; the original observations below are preserved.

The installed `E:\questasim64_2024.1\win64` tools can run simulations with the
existing local license configuration. An independent [probe](probe.txt) printed
`QUESTA_PROBE_PASS`. No license or system PATH setting was changed.

PATH resolves the older ModelSim 10.4 first. Select Questa explicitly for this
project, from the repository root:

```powershell
$env:APB_UART_QUESTA_BIN = 'E:\questasim64_2024.1\win64'
pwsh -NoProfile -File scripts/run_apb_regblock.ps1 -Seed 1702
pwsh -NoProfile -File scripts/run_apb_regblock.ps1 -Seed 1702 -InjectFault
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_learning_baud_test -Seed 1701
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 71
```

Tests used an isolated checkout of `0fe2d95` plus one compatibility fix:
`regblock_checker.write(apb_item t)` now matches the formal argument name of
`uvm_subscriber.write(T t)`. The [initial compilation failure](initial-signature-error.txt)
is retained. All references in that method were renamed consistently; the
stimulus and register oracle are unchanged. ModelSim 10.4 and Verilator had
accepted the old name, whereas Questa 2024.1 rejects it with `vlog-2911`.

## Actual results

Tool: Questa Sim-64 2024.1, build 2024.02 (2024-02-01), bundled UVM 1.1d;
PowerShell 7.6.5. These are actual executions, not mocked tool checks.

| Check | Seed | Functional observation | Runner result | Log |
| --- | --- | --- | --- | --- |
| APB baseline | 1702 | 12 transfers; UVM ERROR/FATAL/WARNING all 0 | PASS, exit 0 | [baseline](apb-baseline.txt) |
| APB injected fault | 1702 | 12 transfers; exactly two REGBLOCK_DATA; FATAL/WARNING 0 | EXPECTED_FAULT_DETECTED, exit 0 | [fault](apb-fault.txt) |
| BAUD learning | 1701 | Completed; UVM ERROR/FATAL/WARNING all 0 | FAIL, exit 1, due to two cold-optimization tool warnings | [learning](uart-learning.txt) |
| UART loopback | 71 | Completed; TX=6/RX=6; UVM ERROR/FATAL/WARNING all 0 | PASS, exit 0 | [loopback](uart-loopback.txt) |

The first main-UART optimization emitted `vopt-10587` (legacy `+acc` disables
optimizations) and `vopt-13408` (coverage disabled for some design units).
The existing zero-tool-warning acceptance rule rejected that learning run.
The subsequent loopback reused the optimized design and emitted no such
warnings. It is not evidence of a warning-free cold start. The learning test
was not repeatedly rerun to obtain a passing cache-dependent receipt.

Both UART runs generated nonempty UCDB files locally, at
`E:\UVM\questa2024-checks\reports\uart_learning_baud_test_1701.ucdb` and
`uart_loopback_test_71.ucdb`. No coverage totals or full-regression result
are claimed. The [manifest](manifest.json) records their hashes and sizes.

Questa 2024.1 usability and licensing are established. The legacy ModelSim
10.4 license failure remains a separate historical result. Strict acceptance
of all four commands on a clean Questa 2024.1 build is still incomplete:
the remaining task is to review the visibility/coverage options responsible
for the cold-start warnings, then rerun the affected UART checks from a fresh
work library. The warning gate was not relaxed or suppressed.

The same signature fix was also checked with the existing Verilator 5.054 /
UVM 2020.3.1 paired runner, seed 1702. Both the [baseline](verilator-baseline.txt)
and [specified fault](verilator-fault.txt) matched expectations; the
[console](verilator-console.txt) records exit-success markers for both.

[Earlier merge review](../README.md) · [Release draft](../../../docs/release_learning_update_draft.md)
