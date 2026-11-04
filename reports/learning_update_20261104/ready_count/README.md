# UART TX ready counter investigation - 2026-11-04

**Not fixed. Do not merge PR #1 under the full-coverage criterion.** The new
clean 60-run campaign passes its runtime checks but still fails the original
UART TX statement gate. No RTL, test-plan, threshold or waiver change was
adopted. This record supplements, rather than replaces, the earlier results.

## New execution evidence

PR head before this investigation: `d9ebc199d07132b4352f75e243a9a140d5ee6aab`.
Tools: Questa Sim-64 2024.1, bundled UVM 1.1d / `QUESTA_UVM-1.2.3`,
PowerShell 7.6.5. VCD inspection used vcdvcd 2.6.0 / Python 3.12.

| Check | Executed version | Actual result | Evidence |
| --- | --- | --- | --- |
| Full default plan, base seeds 101/201/301 | Clean Git export of `d9ebc19` | PASS 60/60; 20 distinct tests; zero UVM errors/fatals/warnings | [Summary](full/regression-summary.md), [individual receipts](full/run-receipts.json) |
| Functional / assertion / directive gates | Same new campaign | PASS 69/69, 66/66, 16/16 | [Native totals](full/coverage-totals.txt) |
| Original RTL gates | Same new campaign | FAIL 18/19; TX statements 26/28 = 92.85%, minimum 95% | [Gate](full/rtl-coverage-gate.md), [native statement details](full/uart-tx-statements.txt) |
| Merge and native text/HTML reports | Same 60 fresh UCDBs | Seven steps completed with zero errors/warnings; overall pipeline exit 1 | [Manifest](full/manifest.json), `full/vcover_01.txt` through `full/vcover_07.txt` |
| Minimal original-RTL reproducer | `d9ebc19` RTL plus the diagnostic bench in this directory | Behavior PASS: 13 known-value events including initialization; line 23 count 0; 28 statement bins retained; diagnostic exit 1 | [Result](probe-result.json), [runtime](probe-run.txt), [native counters](probe-statements.txt) |
| Full-UVM loopback signal inspection, seed 71 | `d9ebc19` plus diagnostic visibility/single-term collection only | PASS TX=6/RX=6; ready has 12 actual transitions after initialization, but line 23 count remains 0 | [VCD event receipt](loopback-ready-events.json), [native counters](singleterm-tx.txt) |

The new full campaign ran from a fresh source export at
`reports/gate_selftests/ready-full-clean`, not an existing simulator library.
No compiled library or UCDB is tracked/delivered by that export. The runner
created 60 new individual databases and merged only the selected test/seed
matrix. All 105 execution-input hashes remained unchanged; they also match
the candidate after CRLF/LF normalization. Exact bytes and run hashes are in
[regression-summary.json](full/regression-summary.json) and the manifest.

The full archive contains only this campaign's selected logs, UCDBs, reports,
HTML and executed inputs. Tracked historical text reports also exist in a Git
source export; old pass-only `final_regression_manifest`, `source_manifest`
and `coverage_manifest` files were **not** treated as new output or included
as this run's manifests. The gate failure occurs before those success-only
manifests are written. [full/manifest.json](full/manifest.json) is the new
failure receipt. Earlier `questa_full/` files remain unchanged.

## What Is Established

The assignment is `assign ready_o = (state == TX_IDLE);` at RTL line 23.
Its RHS/state changes and output transitions occur in real simulation. The
zero is already present in the **live simulator coverage report**, before
UCDB saving, so this is not merely a merge/report parser error. An immediate
save also preserves the zero ([report](immediate-all.txt)).

The same mismatch reproduces without APB, UVM, a scoreboard, FIFO traffic,
or a parent module, using the original `rtl/uart_tx.sv` directly. This localizes
the remaining issue to Questa 2024.1's legacy statement collection for this
construct; it is not evidence that a new UART traffic test is missing. A
specific internal simulator defect/cause has **not** been confirmed by Siemens.

Targeted controls were not promoted to production configuration:

- Explicit `-coverconstruct ca` retains 28 statements but still counts line 23
  as zero ([report](ca_cli-all.txt)).
- Disabling FSM collection and using `-coveropt 1` at both compile and
  optimization stages still gives zero ([report](no_fsm-all.txt)). Thus FSM's
  documented optimization floor is not a sufficient explanation of the issue.
- Single-term coverage, retained delta events, signal-assignment optimization
  controls, visibility variants, multi-bit statement counters, and alternate
  continuous-assignment scheduling did not restore the legacy counter. Native
  tool errors during exploratory options were rejected, not counted as passes.
- `-ngcoverage -coverconstruct ca` does mark line 23 hit, but changes the metric
  to **10 blocks instead of 28 statements** ([report](ng_ca-all.txt)). It was
  rejected: block coverage cannot satisfy the original statement threshold.

These are diagnostic controls, not new accepted hardware configurations. No
counter was edited, no coverage item excluded, and no illegal FSM state forced.

## Reproduce Before Another Full Campaign

From the repository root, choose an output directory that does not yet exist:

```powershell
$env:APB_UART_QUESTA_BIN = 'E:\questasim64_2024.1\win64'
pwsh -NoProfile -File reports/learning_update_20261104/ready_count/run_probe.ps1 -OutputDir E:\UVM\ready-probe-new
```

The diagnostic compiles the original RTL, checks actual ready activity,
requires all 28 statement bins and reads the native statement count. On the
recorded installation it prints `UNRESOLVED_COUNTER_MISMATCH` and exits 1.
Compiler/license/runtime/report errors throw instead; they cannot produce
`COUNTER_OBSERVED` or be called expected fault detection. The probe is not a
full functional/coverage acceptance test and is not added to the 20-test plan.

**Minimum remaining action:** run this reproducer with a vendor-supported
patch/configuration or another available licensed version. First require a
positive line-23 count while retaining all 28 original statement items and
the legacy metric. A specific fixed version is not yet known. Only after
that succeeds, rerun the complete 20-test / three-seed campaign and the same
functional/assertion/directive and 19 RTL gates. A passing diagnostic alone
does not unblock merge.

## Acceptance Boundaries

- **PASS:** new 60/60 runtime checks; functional, assertion and directive gates;
  fresh database/run receipts and source identity checks.
- **FAIL:** original UART TX statement threshold; overall process exit 1.
- **BLOCKED:** full-coverage merge acceptance, pending correct original-metric
  instrumentation. This is not a license failure in the new Questa runs.
- **Expected fault detected, reused:** the earlier independent APB regblock
  fault evidence remains applicable; this documentation/reproducer update
  changes no APB package, checker, UART/UVM execution source or runner.
- **Not newly verified:** a repaired counter, a patched simulator, complete
  release acceptance, new parameter/no-probe/mutation campaigns or physical
  CDC/synthesis signoff. BAUD-learning and the APB pair retain their earlier
  [cold-start evidence](../questa_cold/README.md), not new runs in the 20-test plan.

Historical results and `docs/thesis/` are unchanged. The PR remains draft;
there is no merge, Release publication or claim that the issue is solved.
