# Configuration Apply Timing Summary

- Date: `2026-09-03`
- Test: `uart_config_latency_test`
- Result: `PASS`

| Clock setup | Seed | Register | APB done | UART apply | Observed latency |
| --- | ---: | --- | ---: | ---: | ---: |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 102 | BAUD | 130 ns | 180 ns | 50 ns |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 102 | CTRL | 250 ns | 380 ns | 130 ns |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 202 | BAUD | 130 ns | 180 ns | 50 ns |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 202 | CTRL | 250 ns | 380 ns | 130 ns |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 302 | BAUD | 130 ns | 180 ns | 50 ns |
| PCLK 10 ns, UART clock 40 ns, phase 0/0 | 302 | CTRL | 250 ns | 380 ns | 130 ns |
| PCLK 14 ns, UART clock 22 ns, phase 2/5 ns | 731 | BAUD | 156 ns | 214 ns | 58 ns |
| PCLK 14 ns, UART clock 22 ns, phase 2/5 ns | 731 | CTRL | 268 ns | 324 ns | 56 ns |

The test waits for both `cfg_apply` and the requested target value. It checks
that UART-domain application occurs strictly after the APB write completes;
the latency itself is intentionally not fixed because the clocks are
asynchronous and the mailbox may already have a request in flight.
