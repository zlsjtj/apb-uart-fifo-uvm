# Hands-on UVM learning and APB reuse

Release notes draft; version and publication date pending review.

- Work through three exercises: FIFO negative controls, APB completion-edge sampling, and TX completion.
- Add your first registered UVM test with explicit BAUD normalization and readback expectations.
- Reuse the shared APB agent with a three-register DUT and an independent monitor-driven checker.
- Run the free FIFO checks with Icarus 12.0, or the paired APB UVM example with Verilator 5.054 and Accellera UVM 2020.3.1.

From the repository root:

```bash
bash scripts/run_fifo_smoke.sh
UVM_HOME=/path/to/uvm-core APB_UART_VERILATOR=/path/to/verilator \
  JOBS=2 SEED=1702 bash scripts/run_apb_regblock_verilator.sh
```

The recorded UART pilot covers `uart_learning_baud_test` (seed 1701) and
`uart_loopback_test` (seed 71, TX=6/RX=6) with the declared Verilator/UVM setup.
The APB baseline/fault pair was rerun successfully on 2026-11-04 with the same
tool/library versions and seed 1702; the fault produced exactly two expected
`REGBLOCK_DATA` mismatches across 12 observed transfers.
ModelSim 10.4 compilation passed; its local UVM simulation remains blocked by
license availability. Questa 2024.1 / bundled UVM 1.1d passed BAUD learning,
UART loopback and the APB baseline/fault pair from four independent clean
libraries. Modern visibility controls and separate DUT code instrumentation
resolve the cold-start warnings without suppression. See the
[Questa record](../reports/learning_update_20261104/questa_cold/README.md).
The Questa 2024.1 reporting CLI is now migrated. A new default 20-test campaign
across three base seeds passed 60/60 runtime checks and hit all 69 functional
bins, 66 assertions and 16 directives. **This release draft remains on hold:**
the original RTL gate passes 18/19, with UART TX statements at 92.85% versus
the required 95%. No threshold or waiver was relaxed. See the
[expanded acceptance record](../reports/learning_update_20261104/questa_full/README.md).
The v0.1.0 validation totals retain their original source and scope.

[Exercises](../examples/learning/README.md) ·
[Add a test](adding_first_test.md) ·
[APB reuse and setup](../examples/apb-regblock/README.md) ·
[Validation](learning_update_validation.md)
