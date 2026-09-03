# Baud Tick Mutation Summary

- Time: `2026-09-03 17:02:56`
- Mutation: force enabled serial tick high (`UART_MUTATE_BAUD_TICK_FAST`)
- Test: `uart_baud_timing_test`
- Seed: `96`
- Isolated simulation library: `work_baud_mutation`
- Independent timing checker reported a failure: `True`
- Result: **PASS (mutation detected)**
- Log: `logs/mutation_baud_tick_fast_96.log`

This script passes only when the injected baud-generator fault is detected.
