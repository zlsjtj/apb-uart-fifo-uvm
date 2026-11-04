# Questa 2024.1 full regression and coverage - 2026-11-04

**Overall acceptance: FAIL. Do not merge PR #1 against the expanded full-coverage
criterion yet.** The report entry is migrated and all runtime tests pass, but
the unchanged RTL gate rejects `uart_tx` statement coverage.

| Check | Actual result | Evidence |
| --- | --- | --- |
| Default test plan | 20 distinct tests, each across base seeds 101/201/301; 60/60 PASS | [Summary](regression-summary.md) |
| Individual logs/UCDBs | 60 fresh nonempty databases; every run has TEST_DONE/SB_SUMMARY and zero UVM errors/fatals/warnings | [Source and run data](regression-summary.json) |
| Functional bins | 69/69, zero misses | [Totals](coverage-totals.txt) |
| Assertions | 66/66, zero misses | [Functional/assertion gate](functional-assertion-gate.json) |
| Cover directives | 16/16, zero misses | Same gate |
| RTL gates | 18/19 PASS; UART TX statements FAIL | [Unmodified-threshold results](rtl-coverage-gate.md) |
| Report pipeline | Merge, summary, functional, code, assertion/directive, DU and HTML commands: zero errors/warnings | `vcover_01.txt` through `vcover_07.txt` |
| HTML | Generated, including supporting pages | Local archive and manifest |
| Process exit | 1, caused by the RTL coverage gate | Manifest overall status |

Tools: Questa Sim-64 2024.1, UVM 1.1d, vendor extension
`QUESTA_UVM-1.2.3`, PowerShell 7.6.5. The final run used a new detached
checkout at `E:\UVM\questa-full-final`, based on `44f150e` plus the recorded
migration patch. No old work library, merged data or individual UCDBs were
present before execution. Source bytes were checked against every recorded
hash after the run, and against the candidate working tree after newline
normalization. The exact executed source is in [manifest.json](manifest.json).

## Blocking Gate

`uart_tx` statements: **26/28 = 92.85%, required >=95%**. No threshold,
waiver, test plan, RTL or UVM behavioral source was changed.

The detailed [statement excerpt](uart-tx-statements.txt) has two zero-count
items in `rtl/uart_tx.sv`:

- Line 23: the continuous assignment `assign ready_o = (state == TX_IDLE);`.
- Line 76: the defensive invalid-state default branch.

The first item's zero count despite completed traffic needs an instrumentation
or visibility investigation; its cause is not established here. Controlled
diagnostics with coverage optimization level 1 and explicit hierarchy depth
did not restore the count. A wildcard selection produced a tool warning and
was rejected. Line-debug compilation also failed the zero-warning gate.
Those variants were not adopted or counted as accepted results. No invalid
state was forced merely to make the percentage pass.

The smallest remaining action is to explain and correctly measure the
`ready_o` assignment under Questa 2024.1, retaining all 28 statement items
and the 95% threshold. If a genuine legal stimulus gap is identified, add a
justified check rather than suppressing a bin. Then rerun the fixed full
campaign and original gates. This PR remains draft until that result is reviewed.

## Migration

The default modern path replaces legacy `-totals/-bydu/-file/-htmldir`
with `-summary/-du=*/-output`. Summary categories explicitly include
`-cvg -assert -directive`; selecting only `-code` in the modern reporter
omits those metrics. The legacy command path is retained.

The functional gate accepts the modern `Directives` label as the legacy
`Cover Directives` metric, still requiring positive bin counts, all hits,
zero misses and exactly one row. DUT statements accept `Statements` as
the legacy `Stmts` label. Modern split FSM states/transitions use the same
equal-weight percentage mean as the old `FSMs` report; the actual policy
thresholds and waiver definitions are unchanged.

Every `vcover` invocation now retains its transcript and rejects native errors
or warnings. Complete reports and HTML are generated before the RTL gate so
failed coverage can be inspected; the failure still propagates as exit 1.
The final-regression manifest's UVM version description now reads the actual
first-run banner instead of a hardcoded vendor extension version.

Report-format and gate tests passed **12/12**, covering old/new equivalent
results, misses, zero/missing/duplicate summaries, unchanged FSM averaging,
below-threshold statements/FSM and inconsistent FSM counts. Existing negative
gates passed **19/19** and workflow integrity **25/25**. These are script tests,
not additional UVM runs or another hardware campaign.

## Evidence and Run Boundaries

The authoritative final campaign is only the 60 runs in `questa-full-final`.
The earlier diagnostic campaign in `questa-full-coverage` also ran 60/60,
then correctly failed when its first summary command omitted functional
categories. A report-only diagnostic replay used copies of those earlier
UCDBs and exposed the RTL gate failure. Neither set was mixed into the final
60 databases or used to replace failing cells. The ledger and retained log
hashes are in the manifest.

The complete local `final-evidence.zip` includes all 60 logs and UCDBs,
merged UCDB, detailed text/HTML reports and the exact executed sources.
Its path, SHA-256 and size are recorded in the manifest. Local HTML entry:
`E:\UVM\questa-full-final\reports\final_regression\coverage\html\index.html`.
This is a review artifact, not a GitHub Release or an uploaded evidence asset.

Historical v0.1.0 results retain their original source/date/scope. This run
does not replace historical numbers, establish synthesis/CDC signoff or rerun
parameter, no-probe and mutation campaigns. `docs/thesis/` remains untouched.

[Validation index](../../../docs/learning_update_validation.md) ·
[Release draft on hold](../../../docs/release_learning_update_draft.md)
