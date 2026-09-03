# Architecture Structural Summary

- Time: `2026-09-03 16:55:41`
- Result: `PASS`
- Checks: `21/21`

| Check | Result |
| --- | --- |
| TX monitor does not use DUT bit_tick | PASS |
| RX monitor does not use DUT bit_tick | PASS |
| UART driver does not use DUT bit_tick | PASS |
| Public UART interface contains no white-box probe signals | PASS |
| White-box probe interface exists | PASS |
| TX monitor uses effective BAUD configuration | PASS |
| RX monitor uses effective BAUD configuration | PASS |
| Shared environment configuration exists | PASS |
| Predictor has no hard-coded FIFO depth | PASS |
| Predictor derives FIFO depth from configuration | PASS |
| Virtual sequencer exists | PASS |
| Cross-interface virtual sequence exists | PASS |
| Frame-error flow uses a virtual sequence | PASS |
| RX FIFO flow uses a virtual sequence | PASS |
| Reset/CDC flow uses a virtual sequence | PASS |
| Environment config exposes no unsupported frame-format knobs | PASS |
| Sequence compatibility include uses feature fragments | PASS |
| Test compatibility include uses feature fragments | PASS |
| One-command acceptance entry point exists | PASS |
| FIFO control mutation check exists | PASS |
| Baud-tick mutation check exists | PASS |
