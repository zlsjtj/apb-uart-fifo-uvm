# Teaching-core timing budget, NOT a board pin/oscillator specification.
create_clock -name pclk -period 10.000 [get_ports pclk]
create_clock -name uart_clk -period 40.000 [get_ports uart_clk]
# Cross-domain exceptions are applied to the actual post-synthesis endpoints
# in vivado_synth.tcl. Do not blanket-cut data paths whose delay is bounded.
set_input_delay -clock pclk -max 2.0 [get_ports {psel penable pwrite paddr[*] pwdata[*]}]
set_input_delay -clock pclk -min 0.0 [get_ports {psel penable pwrite paddr[*] pwdata[*]}]
set_output_delay -clock pclk -max 2.0 [get_ports {prdata[*] pready pslverr irq_o}]
set_output_delay -clock pclk -min 0.0 [get_ports {prdata[*] pready pslverr irq_o}]
# RX remains the explicitly synchronous-sampling teaching interface. This
# constraint does not qualify an asynchronous external UART receiver.
set_input_delay -clock uart_clk -max 2.0 [get_ports rx_i]
set_input_delay -clock uart_clk -min 0.0 [get_ports rx_i]
set_output_delay -clock uart_clk -max 2.0 [get_ports tx_o]
set_output_delay -clock uart_clk -min 0.0 [get_ports tx_o]
set_false_path -from [get_ports {presetn uart_rst_n}]
