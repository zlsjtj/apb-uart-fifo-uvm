@{
  Cases = @(
    @{ Id = 'tx_lsb'; Name = 'TX 数据位翻转'; Define = 'UART_MUTATE_TX_LSB'; Test = 'uart_loopback_test'; Seed = 71; Detector = 'SB_TX_MISMATCH|LOOPBACK' }
    @{ Id = 'irq_low'; Name = 'IRQ 恒低'; Define = 'UART_MUTATE_IRQ_STUCK_LOW'; Test = 'uart_irq_test'; Seed = 81; Detector = 'IRQ_STATUS|irq_matches_rx_state' }
    @{ Id = 'fifo_full_low'; Name = 'RX FIFO full 恒低'; Define = 'UART_MUTATE_FIFO_FULL_STUCK_LOW'; Test = 'uart_rx_fifo_full_test'; Seed = 91; Detector = 'RX_FIFO_FULL|SB_RX_MISMATCH|rx_full_blocks_write' }
    @{ Id = 'baud_fast'; Name = '波特率 tick 过快'; Define = 'UART_MUTATE_BAUD_TICK_FAST'; Test = 'uart_baud_timing_test'; Seed = 96; Detector = 'BAUD_TIMING' }
    @{ Id = 'rx_lsb'; Name = 'RX 数据位翻转'; Define = 'UART_MUTATE_RX_LSB'; Test = 'uart_external_rx_test'; Seed = 1011; Detector = 'SB_RX_MISMATCH|EXT_RX' }
    @{ Id = 'rx_empty_high'; Name = 'RX FIFO empty 恒高'; Define = 'UART_MUTATE_RX_EMPTY_STUCK_HIGH'; Test = 'uart_external_rx_test'; Seed = 1012; Detector = 'EXT_RX|SB_RX_LEFT|SEQ_EXP_ERR' }
    @{ Id = 'cfg_apply_drop'; Name = '配置 apply 丢失'; Define = 'UART_MUTATE_CFG_APPLY_DROP'; Test = 'uart_config_latency_test'; Seed = 1013; Detector = 'CFG_LATENCY|config_changes_only_on_apply' }
    @{ Id = 'cfg_ack_stuck'; Name = '配置 ack 恒定'; Define = 'UART_MUTATE_CFG_ACK_STUCK'; Test = 'uart_config_latency_test'; Seed = 1014; Detector = 'CFG_LATENCY|config_request_eventually_ack' }
    @{ Id = 'irq_high'; Name = 'IRQ 恒高'; Define = 'UART_MUTATE_IRQ_STUCK_HIGH'; Test = 'uart_irq_test'; Seed = 1015; Detector = 'IRQ_STATUS|irq_matches_rx_state' }
    @{ Id = 'frame_err_mask'; Name = '帧错误被屏蔽'; Define = 'UART_MUTATE_FRAME_ERR_MASK'; Test = 'uart_frame_error_test'; Seed = 1016; Detector = 'FRAME_REJECT|FRAME_SETUP|frame_error_seen' }
    @{ Id = 'reset_direct'; Name = '复位直接释放'; Define = 'UART_MUTATE_RESET_RELEASE_DIRECT'; Test = 'uart_reset_cdc_test'; Seed = 1017; Detector = 'reset_release_has_sync_latency' }
  )
}
