@{
  RegressionTests = @(
    'uart_reg_test'
    'uart_config_latency_test'
    'uart_ral_test'
    'uart_loopback_test'
    'uart_baud_loopback_test'
    'uart_baud_timing_test'
    'uart_irq_test'
    'uart_frame_error_test'
    'uart_external_rx_test'
    'uart_external_rx_baud_test'
    'uart_rx_fifo_full_test'
    'uart_reset_cdc_test'
    'uart_fifo_full_test'
    'uart_bad_access_test'
    'uart_random_test'
    'uart_recover_test'
  )

  StressProfiles = @(
    @{
      Name = 'skew_7_11'
      Seed = 731
      PclkHalfNs = 7
      UartHalfNs = 11
      PclkPhaseNs = 2
      UartPhaseNs = 5
      Tests = @(
        'uart_config_latency_test'
        'uart_loopback_test'
        'uart_external_rx_test'
        'uart_external_rx_baud_test'
        'uart_reset_cdc_test'
      )
    }
    @{
      Name = 'skew_9_13'
      Seed = 751
      PclkHalfNs = 9
      UartHalfNs = 13
      PclkPhaseNs = 4
      UartPhaseNs = 1
      Tests = @(
        'uart_config_latency_test'
        'uart_frame_error_test'
        'uart_external_rx_baud_test'
        'uart_rx_fifo_full_test'
        'uart_reset_cdc_test'
      )
    }
  )
}
