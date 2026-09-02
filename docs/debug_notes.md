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

`CTRL` and `BAUD` are transferred into the `uart_clk` domain through a
request/acknowledge mailbox. The payload remains stable until it is captured,
so the UART domain does not observe a mixed multi-bit configuration. `BAUD` is
then used to generate a single-cycle `baud_tick`. The TX and RX models advance
one serial bit per tick.
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

## Frame Error Recovery

`uart_frame_error_test` drives a low stop bit through the active UART agent.
The receiver rejects that byte, keeps RX empty and reports the frame error in
STATUS. The error flag remains set until reset, disable, or completion of a
later valid frame; this makes the APB-visible status deterministic instead of
a one-tick pulse. The flag is synchronized into `pclk` before STATUS reads it.
The same test then sends a valid byte, checks that the error clears, IRQ
asserts for the pending data, and the byte can be read normally.

## RX FIFO Full and Recovery

`uart_rx_fifo_full_test` sends 17 external frames without APB reads. The first
16 bytes fill the configured FIFO; the extra frame is rejected while full.
The APB side checks `rx_full`, `rx_empty` and IRQ, reads the accepted bytes in
order, waits for the cross-domain flags to settle, and verifies the FIFO can
accept a new byte afterward. The scoreboard models the 16-entry capacity so a
full-FIFO drop is distinguished from an unexplained data loss.

## Reset and Clock-ratio Stress

The testbench clock half-periods and initial phases are controlled by plusargs.
`uart_reset_cdc_test` checks a combined reset while TX data is pending, then
APB-only and UART-only resets. After each reset it checks register/FIFO/IRQ
state and completes a fresh loopback transfer.

The two FIFO instances derive their reset request from
`presetn && uart_rst_n`. This means either domain reset intentionally flushes
the whole FIFO instead of leaving one pointer at zero and the other at an old
value. Assertion remains asynchronous, while each FIFO side releases through a
two-stage synchronizer in its local clock domain. APB configuration is still
reset only by `presetn`; a UART-only reset therefore preserves CTRL and BAUD
while clearing the serial state and FIFOs.

## Independent BAUD Timing Check

`uart_baud_timing_test` sends `0x55`, whose alternating data bits create a TX
transition at every frame-bit boundary. Starting from the start-bit falling
edge, the checker measures nine consecutive widths directly on `tx_o` and
compares them with the measured UART clock period times the programmed divisor.
The checker never reads the internal `bit_tick`. BAUD=0 is expected to normalize
to divisor 1. BAUD updates are supported between frames, not during a frame.
# 受控故障注入

为确认验证环境不是“只会跑通”，增加了 TX FIFO 写数据最低位翻转的编译期开关。故障版本在独立 `work_mutation` 库中运行，`uart_loopback_test` 的 6 个发送字节全部被 scoreboard 以 `SB_TX_MISMATCH` 检出。默认编译不定义该开关，之后的正式回归为 13/13 PASS。完整记录见 `docs/bug_closure_case.md` 和 `reports/mutation_summary.md`。
