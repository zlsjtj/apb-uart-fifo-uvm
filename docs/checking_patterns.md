# Three Checking Patterns

These are reading and adaptation guides to the working APB-UART environment,
not a separate verification library. Run the commands from the repository root
with [PowerShell 7 and the licensed simulator configured](quickstart.md).

[Predict from observations](#predict-from-observations) ·
[Check the completion edge](#check-the-completion-edge) ·
[Pair faults with baselines](#pair-every-fault-with-a-baseline)

## Predict From Observations

**Use this when:** expectations should follow what the interface accepted,
not merely what a sequence intended to send.

Start at `write_apb_pred` in [uart_predictor.svh](../tb/uvm/uart_predictor.svh).
A successful TXDATA write emits an expected TX byte. The serial monitor
independently observes the transmitted frame, and the
[scoreboard](../tb/uvm/uart_scoreboard.svh) compares them. Follow the analysis-port
connections in `connect_phase` of [uart_env.svh](../tb/uvm/uart_env.svh).

```powershell
pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2
```

**Look for:** `Passed 1/1 tests.` in `reports/regression_summary.md` and
`[SB_SUMMARY]` in `logs/uart_loopback_test_2.log`. The scoreboard must consume
its expectations; unconsumed bytes also fail the test. Without a simulator,
follow the [recorded six-byte loopback](../examples/loopback/README.md).

**Adapt it:** define your protocol's accepted transaction, error handling, and
reset behavior first. Replace UART-specific items, register decoding, and
configuration state. Keep the expected and actual streams separate. Here,
loopback RX expectations come from observed TX frames; external RX expectations
come from the RX pin monitor, not the stimulus driver.

## Check the Completion Edge

**Use this when:** a driver and monitor may be agreeing on the same incorrect
sampling convention.

Read [apb_contract_tb.sv](../tb/unit/apb_contract_tb.sv), especially the APB
read/write tasks and their `@(posedge pclk)` checks. This test instantiates the
RTL without the UVM APB driver. Compare it with the `input #1step` clocking
blocks in [apb_if.sv](../tb/interfaces/apb_if.sv).

```powershell
pwsh -NoProfile -File scripts/run_contract_tests.ps1 -Widths 4
```

**Look for:** `APB contract and FIFO parameter tests passed: 1/1`, plus
`APB_CONTRACT_PASS` in `logs/apb_contract_width_4.log`. The report is
`reports/contract_tests.json`. `Widths 4` means FIFO address width 4, hence
depth 16; it runs the functional/wraparound case, not four tests.

**Adapt it:** derive expected reset values, legal addresses, and error responses
from the interface contract. This target has zero wait states. For a target
with wait states, change the transfer and sampling logic to wait for the actual
completion handshake. Do not copy a fixed post-edge delay into the checker.

The [original debugging case](bug_closure_case.md#english) explains the shared
2 ns sampling mistake; the [new VCD comparison](../examples/apb-timing/README.md)
shows the fixed design against a controlled reintroduction of the fault.

## Pair Every Fault With a Baseline

**Use this when:** a passing regression is not enough to show that a particular
checker would detect a defect.

Find `apb_late` in [mutation_plan.psd1](../config/mutation_plan.psd1).
It selects a compile-time RTL mutation, `uart_reg_test`, seed 1071, and the
allowed detector messages. Read the paired execution in
[run_mutation_campaign.ps1](../scripts/run_mutation_campaign.ps1) and the
`Get-MutationOutcome` classification in [evidence_common.ps1](../scripts/evidence_common.ps1).

```powershell
pwsh -NoProfile -Command '& ./scripts/run_mutation_campaign.ps1 -CaseIds apb_late'
```

**Look for:** `Mutation campaign passed: 1/1` and the paired baseline/fault
records in `reports/mutation_campaign.json`. The baseline must pass, and the
mutant must produce an actual failure from a declared detector. A compile
error, license error, or timeout is not a successful detection. The
[saved sample](../examples/apb-timing/README.md) includes the resulting failure
messages and source identity.

**Adapt it:** choose one specific fault and the checker that should detect it.
Keep the test, seed, clocks, and other settings identical for both runs. Add the
fault through the existing plan and isolated compile mechanism; do not replace
the normal design with a broken version or count unrelated failures as success.

## Next Reads

[Follow one byte through UVM](../README.md#follow-one-byte-through-uvm) ·
[Cross-clock and recovery scenarios](../config/verification_plan.psd1) ·
[TX completion case](tx_completion_case.md#english) · [Documentation index](README.md)
