module apb_uart_serial_core (
  input  logic        uart_clk,
  input  logic        uart_rst_n,
  input  logic        enable,
  input  logic        loopback,
  input  logic [31:0] baud_value,
  input  logic        rx_i,
  input  logic [7:0]  tx_fifo_rdata,
  input  logic        tx_empty,
  input  logic        rx_full,
  output logic        tx_o,
  output logic        tx_rd_en,
  output logic        tx_retired,
  output logic [7:0]  rx_data,
  output logic        rx_valid,
  output logic        rx_frame_err,
  output logic [31:0] baud_count,
  output logic [31:0] baud_divisor,
  output logic        baud_tick,
  output logic        serial_bit_tick
);
  logic tx_ready;
  logic serial_rx;

  assign serial_rx = loopback ? tx_o : rx_i;

  uart_baud_gen u_baud_gen (
    .clk        (uart_clk),
    .rst_n      (uart_rst_n),
    .enable     (enable),
    .baud_value (baud_value),
    .count      (baud_count),
    .divisor    (baud_divisor),
    .tick       (baud_tick)
  );

`ifdef UART_MUTATE_BAUD_TICK_FAST
  assign serial_bit_tick = enable;
`else
  assign serial_bit_tick = baud_tick;
`endif

  assign tx_rd_en = enable && serial_bit_tick && tx_ready && !tx_empty;

  uart_tx u_uart_tx (
    .clk        (uart_clk),
    .rst_n      (uart_rst_n),
    .enable     (enable),
    .bit_tick_i (serial_bit_tick),
    .data_i     (tx_fifo_rdata),
    .valid_i    (tx_rd_en),
    .ready_o    (tx_ready),
    .tx_o       (tx_o),
    .retired_o  (tx_retired)
  );

  uart_rx u_uart_rx (
    .clk         (uart_clk),
    .rst_n       (uart_rst_n),
    .enable      (enable),
    .bit_tick_i  (serial_bit_tick),
    .rx_i        (serial_rx),
    .data_o      (rx_data),
    .valid_o     (rx_valid),
    .ready_i     (!rx_full),
    .frame_err_o (rx_frame_err)
  );
endmodule
