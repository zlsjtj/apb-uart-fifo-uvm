# PR #1 merge review - 2026-11-04

Latest tool check: [four independent Questa 2024.1 cold-start checks passed](questa_cold/README.md).
The license BLOCKED results below concern legacy ModelSim 10.4. The initial
Questa warning-bearing run and its subsequent fix are recorded separately.

Reviewed head: `122d12a91a97a5a0c6c760acef832c23396b446b`.
Base: `3c8a074d27746f3570262aa114f72059a3bb5315`.
At that initial review, `122d12a` was still the latest PR commit and GitHub
reported the draft PR mergeable without conflicts. Its `0fe2d95` follow-up
contained documentation/evidence only. Later toolchain fixes and results are
identified in the linked records above.

Recommendation: merge this scoped learning/reuse update after author review.
No unresolved code blocker was found. All four requested behaviors have
applicable runtime evidence; the current APB pair also passed a fresh run.
Keep ModelSim runtime compatibility explicitly BLOCKED until a valid license
is available. This recommendation does not extend the full UART acceptance
or coverage claims.

## Reused execution evidence

The supplied handoff labels its source snapshot `da63e4b` (2026-11-02).
All 69 execution inputs checked against that source ZIP match the reviewed
head after CRLF/LF normalization: all UART RTL/testbench SV, the shared APB
classes and package, the regblock SV/filelist, both root filelists and the
free APB runner. File hashes and original log hashes are in
[evidence-reuse.json](evidence-reuse.json).

| Verification | Version | Tools | Actual result | Original log |
| --- | --- | --- | --- | --- |
| BAUD learning, seed 1701 | Handoff `da63e4b`; applicable to `122d12a` | Verilator 5.054 / UVM 2020.3.1 | PASS; ERROR=0, FATAL=0; config sequence completed | [uart-learning](historical/uart-learning.txt) |
| UART loopback, seed 71 | Same source equivalence | Same tools | PASS; TX=6, RX=6; ERROR=0, FATAL=0 | [uart-loopback](historical/uart-loopback.txt) |
| APB baseline, seed 1702 | Same source equivalence | Same tools | PASS; observed=12; ERROR=0, FATAL=0 | [apb-baseline](historical/apb-uvm-baseline.txt) |
| APB injected fault, seed 1702 | Same source equivalence | Same tools | Expected fault detected; exactly two REGBLOCK_DATA; observed=12; FATAL=0 | [apb-fault](historical/apb-uvm-fault.txt) |

All four runs reported exactly the two documented `UVM_NO_DPI` warnings,
`NO_DPI_USED` and `NO_VISIT_CHECK`. The original
[VERIFICATION.md](historical/VERIFICATION.md) is preserved with its date,
including the incomplete UART mutation build. These are reused runs, not
four new executions. The ModelSim runner edits do not change their simulated
design, stimulus or checker code. They do require separate runner validation.
The seeds above are supplied by the handoff metadata; the raw runtime logs
identify the tests but do not independently print their seed.

## Earlier local checks on the reviewed head

| Verification | Version | Tools | Actual result | Log |
| --- | --- | --- | --- | --- |
| FIFO | `122d12a` execution inputs | Icarus 12.0 / WSL Ubuntu 24.04 | PASS 8/8; expected faults detected 2/2 | [FIFO summary](current/fifo-local-summary.txt) |
| Regblock RTL contract | Same inputs | Icarus 12.0 | PASS; 12 accesses, exit 0 | [baseline](current/contract-baseline.txt) |
| Regblock RTL fault | Same inputs | Icarus 12.0 | Expected fault detected; CONTRACT_DATA, exit 1 | [fault](current/contract-fault.txt) |
| UART BAUD and loopback commands | Same inputs | ModelSim 10.4 / bundled UVM 1.1d | Compile PASS, zero errors/warnings; simulation BLOCKED by license | [BAUD](current/questa-learning-console-elevated.txt), [loopback](current/questa-loopback-console.txt) |
| APB baseline and fault commands | Same inputs | Same tools | Compile PASS, zero errors/warnings; simulation BLOCKED by license | [baseline](current/regblock-baseline-console.txt), [fault](current/regblock-fault-console.txt) |

## New runner and license checks

The previous `check_runner.ps1` checks the actual acceptance block with two
adapted supplied logs and seven invalid fixtures. Its coverage is adequate
for exact counts/IDs, duplicate summaries, timeout and completion checks, so
those checks were not repeated. It does not cover tool exit status, missing
logs or stale logs across the entire runner.

The supplemental [lifecycle check](check_runner_lifecycle.ps1) runs the complete
PowerShell runner in an isolated fixture project with mocked tools. Normal and
fault fixtures include the ModelSim `# ` log prefix. It verifies distinct
`PASS` and `EXPECTED_FAULT_DETECTED` markers. Eight invalid lifecycle cases
are rejected: license failure with exit 0; nonzero exit with a valid log;
missing log; empty log; stale log not rewritten; compile failure with a stale
log; baseline supplied to fault mode; fault supplied to baseline mode.
Compilation failure also prevents a simulator call.

[Results](current/runner-lifecycle.json): all 10 cases matched expectations,
PowerShell 7.6.5. These are mocked-tool tests, not UVM runtime passes.
Reproduce from the repository root:

```powershell
pwsh -NoProfile -File reports/learning_update_20261104/check_runner_lifecycle.ps1
```

The actual license failures above also made both APB runner modes fail rather
than reporting detection. A finite read-only check found the existing configured
file present, but `lmutil lmdiag` reported no license for either required feature.
No alternate LM_LICENSE_FILE/SALT_LICENSE_SERVER was configured. Configuration
was not changed. [Sanitized diagnosis](current/license-diagnostic.json).

The remaining licensed-tool action is to supply a valid available simulation
feature and run the four commands in
[the local check record](../../docs/learning_update_validation.md). The compiler
result alone does not establish UVM 1.1d runtime compatibility.

## New free UVM run on the reviewed head

| Verification | Version | Tools | Actual result | Log |
| --- | --- | --- | --- | --- |
| APB baseline, seed 1702 | `122d12a` execution inputs | Verilator 5.054 / UVM 2020.3.1 / GCC 13.3.0 | PASS; observed=12; ERROR=0; FATAL=0 | [baseline](current/apb-verilator-baseline.txt) |
| APB injected fault, same seed | Same inputs | Same tools | Expected fault detected; exactly two REGBLOCK_DATA; observed=12; FATAL=0 | [fault](current/apb-verilator-fault.txt) |

Both runs had exactly the two declared UVM library warnings. The unmodified
paired runner checked the full summaries/diagnostic IDs and returned exit 0
only after both outcomes matched expectations. The
[console receipt](current/apb-verilator-console.txt) records the command's
seed, versions, tool/library source commits and separate log locations.

Exact local invocation, from the repository root after building the official
Verilator `v5.054` tag with `autoconf`, `configure` and `make -C src -j2 opt`:

```bash
export VERILATOR_ROOT=/var/tmp/apb-pr1-tools/verilator
UVM_HOME=/var/tmp/apb-pr1-tools/uvm-core \
APB_UART_VERILATOR="$VERILATOR_ROOT/bin/verilator" \
JOBS=2 SEED=1702 bash scripts/run_apb_regblock_verilator.sh
```

Tool source commit: `bbb60a403932a9f695cb6ff001ceb73de6ad9234`.
UVM source commit: `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.
Full compiler logs remain locally at
`logs/apb-regblock/verilator_{baseline,fault}_1702/compile.log`;
[manifest.json](manifest.json) records their hashes and sizes. The
[initial bootstrap failure](current/tool-bootstrap.txt) did not execute UVM
and is not counted as fault detection.

The two UART tests did not need another build/run: all their simulation
inputs match the supplied source and their existing runtime evidence was
checked above. This fresh pair supplements the current APB/free-runner
evidence rather than inflating a UART regression total.

## Scope

PASS and expected-fault detection above cover the four requested behaviors
through applicable runtime evidence, plus the runner's result handling.
BLOCKED: local ModelSim UVM execution. Not revalidated: the complete 20-test
UART campaign, UART mutations, UCDB/coverage and synthesis. Historical 60/60,
13/13 and 69/69 totals retain their original version and scope. The untracked
`docs/thesis/` in the primary checkout is untouched.
