# Learning update: local checks on 2026-11-04

This check applies to the learning/reuse patch based on
`3c8a074d27746f3570262aa114f72059a3bb5315`, plus the PowerShell runner fixes
described below. It does not change the v0.1.0 evidence or its reported totals.

## Commands and results

Commands ran from the repository root. Windows used PowerShell 7 and
ModelSim SE-64 10.4 with its bundled UVM 1.1d. The free RTL checks ran in
Ubuntu 24.04 under WSL with Icarus 12.0.

| Command | Observed result |
| --- | --- |
| `bash scripts/run_fifo_smoke.sh` | 8/8 baselines passed; 2/2 specified faults detected |
| `iverilog -g2012 -s tb_regblock_contract -o /tmp/regblock-contract examples/apb-regblock/regblock.sv examples/apb-regblock/tb_regblock_contract.sv` then `vvp /tmp/regblock-contract` | `RTL_CONTRACT_PASS: 12 accesses`, exit 0 |
| Same RTL command with `-DREGBLOCK_INJECT_FAULT`, then run | Exit 1 at `CONTRACT_DATA addr=04 expected=a5a55a5a got=a5a55a5b`; no pass marker |
| `pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_learning_baud_test -Seed 1701` | Compilation: 0 errors, 0 warnings. Simulation blocked by license checkout |
| `pwsh -NoProfile -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 71` | Compilation: 0 errors, 0 warnings. Simulation blocked by license checkout |
| `pwsh -NoProfile -File scripts/run_apb_regblock.ps1 -Seed 1702` | Compilation: 0 errors, 0 warnings. Simulation blocked by license checkout; runner failed |
| `pwsh -NoProfile -File scripts/run_apb_regblock.ps1 -Seed 1702 -InjectFault` | Compilation: 0 errors, 0 warnings. Simulation blocked by license checkout; runner failed |

The simulation diagnostic was:

```text
Failure to obtain a Verilog simulation license. Unable to checkout any of these license features: qhsimvl or msimhdlsim
Error loading design
```

No UVM simulation pass, new UCDB or new coverage result is claimed for these
local attempts. Verilator was not available in this WSL installation, so the
[2026-11-02 pilot](verilator_feasibility.md) was not rerun here.

## Review fixes and static checks

The new Questa runner now requires exactly one summary per UVM severity,
exact counts and diagnostic IDs, and one complete 12-transfer summary.
Previously, its unanchored count match could accept `UVM_ERROR : 20` as a
count of 2. It also rejects simulator warnings and checks the absolute work
library path before removing a previous generated library.

Local parser checks used the supplied baseline/fault logs with the two
Verilator-only warnings removed to exercise the Questa zero-warning policy.
Both adapted fixtures were accepted. Seven altered fixtures were rejected:
20 errors, a nonzero fatal count, a duplicate summary, a wrong detector,
a simulator warning, a watchdog timeout and an incomplete transfer summary.
These are log-parser checks, not simulated hardware results.

The 26 patched files were compared with the supplied source ZIP after newline
normalization; only the reviewed PowerShell runner differed. All 173 local
links in the supplied Markdown changes resolved. Bash and PowerShell syntax
checks passed. The original UART RTL, default 20-test plan and published
evidence were unchanged.

[APB reuse example](../examples/apb-regblock/README.md) ·
[First test](adding_first_test.md) · [Documentation index](README.md)
