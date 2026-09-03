interface uart_probe_if (
  input logic pclk,
  input logic uart_clk
);
  timeunit 1ns;
  timeprecision 1ps;

  // White-box observation only. Drivers and black-box protocol checks must
  // not consume this interface.
  logic        pclk_rst_n;
  logic        uart_clk_rst_n;
  logic        fifo_async_rst_n;
  logic        fifo_pclk_rst_n;
  logic        fifo_uart_rst_n;
  logic        cfg_busy;
  logic        cfg_req_tgl;
  logic        cfg_ack_pclk_q2;
  logic        cfg_uart_initialized;
  logic        cfg_apply_uart;
  logic [2:0]  ctrl_uart_cfg;
  logic [31:0] baud_uart_cfg;
  logic        enable_uart;
  logic        irq_en;
  logic        tx_full;
  logic        tx_push;
  logic        rx_full;
  logic        rx_full_pclk;
  logic        rx_empty;
  logic        rx_pop;
  logic        rx_frame_err;
  logic        rx_frame_err_pclk;
  logic        rx_wr_en;

  clocking uart_mon_cb @(posedge uart_clk);
    default input #1step;
    input cfg_apply_uart;
    input ctrl_uart_cfg;
    input baud_uart_cfg;
    input uart_clk_rst_n;
  endclocking
endinterface
