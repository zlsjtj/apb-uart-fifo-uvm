# Questa 2024.1 cold-start acceptance - 2026-11-04

This four-check result remains valid. The later
[full 20-test coverage campaign](../questa_full/README.md) resolves the CLI
migration item below but fails one original RTL coverage gate; it supersedes
the scoped merge recommendation for the expanded acceptance request.

Recommendation: merge the scoped learning/reuse PR after author review.
All four requested checks now pass their strict gates from independent clean
libraries. No warning was suppressed or accepted. The earlier warning-bearing
[run](../questa2024/README.md) remains archived.

Tested snapshot: `5e9643e` plus the filelist/compiler-option patch recorded by
the executable-input hashes in [verified.json](verified.json). Each case used
its own new detached worktree under `E:\UVM\questa-cold-final-rw\`, initially
without a UART `work` library or APB work directory. Both UART transcripts
show a fresh optimization, rather than loading an existing optimized design.

Tools: Questa Sim-64 2024.1 (2024.02), bundled UVM 1.1d, PowerShell 7.6.5.

| Check | Seed | Strict result | Observed result | Full console |
| --- | --- | --- | --- | --- |
| BAUD learning | 1701 | PASS, exit 0 | UVM ERROR/FATAL/WARNING=0; four BAUD updates completed | [learning](learning.txt) |
| UART loopback | 71 | PASS, exit 0 | TX=6/RX=6; UVM ERROR/FATAL/WARNING=0; VCD saved | [loopback](loopback.txt) |
| APB baseline | 1702 | PASS, exit 0 | 12 transfers; UVM ERROR/FATAL/WARNING=0 | [baseline](apb-baseline.txt) |
| APB injected fault | 1702 | EXPECTED_FAULT_DETECTED, exit 0 | 12 transfers; exactly two REGBLOCK_DATA; FATAL/WARNING=0 | [fault](apb-fault.txt) |

Compilation and optimization reported zero tool errors/warnings in all four
consoles. The expected UVM errors in the fault case remain mandatory.

## Fix

The installed tool's `verror 10587` explains that legacy `+acc` disables
optimizations. Its `vopt -help Debug` documents `-access` and `-debug` as the
modern visibility controls. For the default filelist on Questa 2024 and newer,
the runner now uses `-voptargs="-access=rw+/tb_apb_uart -debug"`, with the
selected top substituted as appropriate. Read/write debug access and VCD
support are retained. The legacy/custom-filelist compile path is unchanged.

`verror 13408` identifies automatic code-coverage exclusion of UVM/OVM/MTI
verification IP. The old command requested code coverage across the DUT and
testbench/UVM compilation. The default modern path now compiles DUT RTL with
`+cover=bcesft`, then compiles the interfaces, packages, SVA and top separately
without requesting library/testbench code coverage. DUT code metrics, SVA
and functional covergroups remain enabled. The composed root filelist still
contains exactly the same 20 SV input files, each once.

The new testbench filelist participates in source hashing, acceptance
snapshots and exported bundles. Fixture tests were updated accordingly.
Compiler logs now also have an explicit zero-error/zero-warning check.
`Get-UvmOutcome`, the UVM warning threshold and RTL coverage policy were not
relaxed. Both original warning IDs still cause a completed baseline to fail
when reintroduced as [diagnostic fixtures](warning-gate.json).

## Coverage and visibility checks

Same test/seed before/after comparisons use the actual UCDB files, not merged
results. The DUT statement/branch/condition/expression/FSM bin counts match
for every module referenced by the existing 19-entry RTL gate policy. This
checks preservation of measured items; it does not assert those coverage
thresholds are all reached by the BAUD test alone.

The [before](before-summary.txt) and [after](after-summary.txt) summaries retain
66 assertion items, 60 covergroup bins and 16 directives for this selected
test. These are bin counts, not all-hit results or replacements for the
historical campaign totals. [Per-DU before](before-code.txt) and
[after](after-code.txt) reports provide the underlying data.

Toggle counts differ under the modern optimization/visibility configuration,
for example `apb_uart_cfg_cdc` 322 to 172 and `apb_uart_regs` 398 to 274.
All differences are listed in `informationalToggleBinChanges` in the JSON
verification record. The existing policy treats toggle coverage as an
observation metric; no threshold or waiver was added/changed, and the counts
are not presented as a coverage improvement.

The actual [VCD](loopback-vcd.txt) contains all 13 requested signals,
six TX enqueue pulses, six RX dequeue pulses and 35 known serial TX changes.
It was parsed with vcdvcd 2.6.0. Both UART runs produced new nonempty UCDBs;
their local paths and hashes are in [manifest.json](manifest.json).

Additional checks: workflow integrity 25/25, including testbench-filelist
source drift; existing negative gates 19/19; root-filelist expansion with
Verilator 5.054 completed successfully. That Verilator check was lint and
elaboration only, not another UART runtime result.

## Remaining scope

The four-check cold-start blocker is resolved. The PR remains draft for
author review; it was not merged and no Release was published. RTL and UVM
behavioral sources, the default 20-test plan, historical 60/60, 13/13 and
coverage evidence, and the primary checkout's `docs/thesis/` are unchanged.

The complete 20-test/coverage/synthesis acceptance campaign was not rerun.
A separate known migration item remains: `merge_coverage.ps1` uses legacy
`vcover report -totals/-bydu/-file`; Questa 2024.1 rejects `-totals` and marks
the other two as deprecated. These were discovered during report inspection.
The successful comparisons here use supported `-summary/-du=*/-output`
options. Full Questa 2024.1 acceptance requires migrating that reporting path
and validating its gates separately; it is not claimed by this four-check run.

[Local validation index](../../../docs/learning_update_validation.md) ·
[Release draft](../../../docs/release_learning_update_draft.md)
