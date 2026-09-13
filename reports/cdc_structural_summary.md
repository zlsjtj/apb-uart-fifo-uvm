# CDC Structural Check Summary

- Time: `2026-09-13 11:59:54`
- Commercial CDC tool available: `False`
- Scope: RTL structural rules only; this is not a replacement for signoff CDC analysis.
- Result: 35/35 checks passed.

| Check | Result | Detail |
| --- | --- | --- |
| Both mailbox domains reset with the shared FIFO epoch | PASS | required structure found |
| APB sees the returned synchronized TX empty flag | PASS | required structure found |
| Startup cannot bypass the synchronized request | PASS | legacy structure absent |
| FIFO full flag is registered in its source domain | PASS | required structure found |
| FIFO empty flag is registered in its source domain | PASS | required structure found |
| Configuration mailbox holds a stable CTRL payload | PASS | required structure found |
| Configuration mailbox holds a stable BAUD payload | PASS | required structure found |
| Configuration request uses a toggle | PASS | required structure found |
| Configuration acknowledgement uses a toggle | PASS | required structure found |
| UART-to-APB acknowledgement synchronizer is marked | PASS | required structure found |
| APB-to-UART request synchronizer is marked | PASS | required structure found |
| Reset-release synchronizer stages are marked | PASS | required structure found |
| Shared FIFO reset asserts on either external reset | PASS | required structure found |
| APB domain uses a reset-release synchronizer | PASS | required structure found |
| UART domain uses a reset-release synchronizer | PASS | required structure found |
| FIFO APB side uses a reset-release synchronizer | PASS | required structure found |
| FIFO UART side uses a reset-release synchronizer | PASS | required structure found |
| UART mailbox uses the synchronized shared reset | PASS | required structure found |
| FIFO ports do not deassert directly from external resets | PASS | legacy structure absent |
| Legacy per-bit CTRL/BAUD synchronizers removed | PASS | legacy structure absent |
| RX full status synchronizer is marked | PASS | required structure found |
| Frame error status synchronizer is marked | PASS | required structure found |
| STATUS uses synchronized UART-domain flags supplied by the top level | PASS | required structure found |
| FIFO read-pointer synchronizer is marked | PASS | required structure found |
| FIFO write-pointer synchronizer is marked | PASS | required structure found |
| FIFO Gray-code conversion is present | PASS | required structure found |
| FIFO uses second-stage synchronized pointers | PASS | required structure found |
| Mailbox payload stability is asserted | PASS | required structure found |
| Request-to-acknowledgement progress is asserted | PASS | required structure found |
| Configuration apply is asserted to be one cycle | PASS | required structure found |
| Acknowledgement changes are tied to apply | PASS | required structure found |
| APB reset-release latency is asserted | PASS | required structure found |
| UART reset-release latency is asserted | PASS | required structure found |
| Mailbox busy and independent-reset stress test exists | PASS | required structure found |
| UART-only reset recovery is exercised | PASS | required structure found |
