# Architecture Structural Summary

- Time: `2026-09-03 17:51:45`
- Result: `PASS`
- Checks: `37/37`

| Check | Result |
| --- | --- |
| TX monitor does not use DUT bit_tick | PASS |
| RX monitor does not use DUT bit_tick | PASS |
| UART driver does not use DUT bit_tick | PASS |
| Public UART interface contains no white-box probe signals | PASS |
| White-box probe interface exists | PASS |
| TX monitor uses APB-observed runtime configuration | PASS |
| RX monitor uses APB-observed runtime configuration | PASS |
| TX monitor is a black-box serial observer | PASS |
| RX monitor is a black-box serial observer | PASS |
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
| Unified reset monitor exists | PASS |
| Reset observer automatically resets the RAL mirror | PASS |
| Predictor consumes the shared reset event | PASS |
| Scoreboard consumes the shared reset event | PASS |
| Coverage consumes the shared reset event | PASS |
| Top level delegates APB registers | PASS |
| Top level delegates configuration CDC | PASS |
| Top level delegates UART serial logic | PASS |
| Serial core delegates baud generation | PASS |
| Declarative regression test list exists | PASS |
| Declarative stress profiles exist | PASS |
| Final regression contains no hard-coded run count | PASS |
| RTL-only coverage policy exists | PASS |
| Machine-readable RTL coverage gate exists | PASS |
