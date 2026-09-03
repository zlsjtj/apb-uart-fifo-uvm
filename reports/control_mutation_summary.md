# IRQ Control Mutation Summary

- Time: `2026-09-03 15:19:11`
- Mutation: force IRQ output low (`UART_MUTATE_IRQ_STUCK_LOW`)
- Test: `uart_irq_test`
- Seed: `81`
- Isolated simulation library: `work_irq_mutation`
- IRQ checker reported a failure: `True`
- Result: **PASS (mutation detected)**
- Log: `logs/mutation_irq_stuck_low_81.log`

This script passes only when the injected IRQ control fault is detected.
