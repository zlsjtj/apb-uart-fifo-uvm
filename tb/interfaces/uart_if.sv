interface uart_if (
  input logic uart_clk,
  input logic uart_rst_n
);
  timeunit 1ns;
  timeprecision 1ps;

  logic rx_i;
  logic tx_o;
  logic bit_tick;
  logic [2:0]  ctrl_uart_cfg;
  logic [31:0] baud_uart_cfg;
  logic        cfg_apply;

  clocking drv_cb @(posedge uart_clk);
    default input #1step output #1ns;
    output rx_i;
    input  tx_o;
    input  bit_tick;
  endclocking

  clocking mon_cb @(posedge uart_clk);
    default input #1step output #1ns;
    input rx_i;
    input tx_o;
    input bit_tick;
    input ctrl_uart_cfg;
    input baud_uart_cfg;
    input cfg_apply;
  endclocking

  task automatic idle_line();
    rx_i <= 1'b1;
  endtask

endinterface
