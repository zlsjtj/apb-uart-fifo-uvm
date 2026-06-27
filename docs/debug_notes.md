# Debug Notes

These are the main implementation details that were checked while bringing up
the testbench.

## APB Sampling

The APB driver drives setup/access phases around the clock edge and samples
`prdata` and `pslverr` after a small delay. The monitor uses the same idea when
publishing transactions. This avoids reading stale values from the same edge
where the DUT updates APB outputs with nonblocking assignments.

Relevant files:

- `tb/uvm/apb_driver.svh`
- `tb/uvm/apb_monitor.svh`

## Loopback Path

`uart_loopback_test` checks this path:

1. Write `CTRL=3` to enable the UART and loopback mode.
2. Write bytes through `TXDATA`.
3. The TX FIFO crosses from `pclk` to `uart_clk`.
4. `uart_tx` serializes the bytes.
5. Loopback routes `tx_o` into `uart_rx`.
6. RX data is stored in the RX FIFO and read back through `RXDATA`.

The scoreboard tracks APB TX writes, UART TX frames, and APB RX reads. In the
sample run, it reported `checked TX=6 RX=6`.

For waveform debug, the regression script can dump the key APB and UART signals
for this test:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_questa.ps1 -Tests uart_loopback_test -Seed 2 -DumpLoopbackVcd
```

The generated VCD is intentionally not committed because it is a local debug
artifact.

## Baud Tick

`BAUD` is synchronized into the `uart_clk` domain and used to generate a
single-cycle `baud_tick`. The TX and RX models advance one serial bit per tick.
Most regression tests set `BAUD=1` to keep runtime short; `uart_baud_loopback_test`
uses `BAUD=4` to check that a slower tick still passes through the loopback path.

## FIFO Checks

The asynchronous FIFO uses binary pointers, Gray-coded pointers, and two-flop
pointer synchronization between clock domains. The tests exercise both normal
traffic and boundary behavior:

- `uart_fifo_full_test` writes enough TXDATA values to hit the full path.
- `uart_bad_access_test` reads empty RXDATA and expects an APB error.

The SVA file also checks that accepted writes do not occur while full and
accepted reads do not occur while empty.

## Assertion Hookup

The FIFO assertions are instantiated next to the TX and RX FIFO instances in
`rtl/apb_uart.sv`. This keeps the assertion hookup explicit and avoids the
ModelSim warning that appears when a `bind` statement is left in compilation-unit
scope.
