# P2 Structural Summary

- Time: `2026-09-03 17:51:45`
- Result: `PASS`
- Checks: `15/15`

| Check | Result |
| --- | --- |
| Independent RX-pin monitor exists | PASS |
| RX monitor decodes observed pin samples | PASS |
| TX monitor uses the APB-observed serial model | PASS |
| RX monitor uses the APB-observed serial model | PASS |
| TX monitor is independent of white-box probes | PASS |
| RX monitor is independent of white-box probes | PASS |
| UART agent builds the RX monitor | PASS |
| Scoreboard does not trust driver transactions | PASS |
| UART driver publishes no expected-result stream | PASS |
| Reference predictor is separate from scoreboard | PASS |
| Expected TX stream connects predictor to scoreboard | PASS |
| Expected RX stream connects predictor to scoreboard | PASS |
| UART-domain configuration apply event exists | PASS |
| APB-write versus UART-apply timing test exists | PASS |
| IRQ control mutation check exists | PASS |
