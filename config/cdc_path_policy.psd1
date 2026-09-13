@{
  Rules = @(
    @{ Id='CDC-W004'; Code='CDC-6'; Source='^u_tx_completion/retired_gray_reg\[[\d:]+\]/C$'; Destination='^u_tx_completion/retired_q1_reg\[[\d:]+\]/D$'; Reason='完整停止位或显式中止后递增完成计数，源域寄存 Gray 后两级同步；明确 max_delay/bus_skew；公开状态边界和多次回绕测试。' }
    @{ Id='CDC-W001'; Code='CDC-6'; Source='^u_(tx|rx)_fifo/[rw]gray_reg\[[\d:]+\]/C$'; Destination='^u_(tx|rx)_fifo/[rw]gray_[rw]clk_q1_reg\[[\d:]+\]/D$'; Reason='Gray 指针源域寄存、两级同步；bus_skew 约束；FIFO 回绕及错相回归。MSB 被综合合并到 bin 寄存器，单独列为同步路径。' }
    @{ Id='CDC-W002'; Code='CDC-15'; Source='^u_cfg_cdc/cfg_(ctrl|baud)_hold_reg\[\d+\]/C$'; Destination='^u_cfg_cdc/(ctrl|baud)_uart_cfg_reg\[\d+\]/D$'; Reason='数据束在请求应答期间保持稳定；接收端只在两级同步请求变化后装载；复位后也走同一握手。' }
    @{ Id='CDC-W003'; Code='CDC-15'; Source='^u_tx_fifo/mem_reg_[^ ]+/(RAMA|RAMA_D1|RAMB|RAMB_D1|RAMC|RAMC_D1|DP)/CLK$'; Destination='^u_serial_core/u_uart_tx/shifter_reg\[\d+\]/D$'; Reason='FIFO 存储由读侧同步写指针及 empty 保护，非空时才装载 shifter；满空及多次回绕用例检查数据。' }
  )
}
