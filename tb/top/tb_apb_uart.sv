`timescale 1ns/1ps

module tb_apb_uart;
  import uvm_pkg::*;
  import uart_pkg::*;
  `include "uvm_macros.svh"

  logic pclk;
  logic presetn;
  logic uart_clk;
  logic uart_rst_n;
  logic irq_o;

  initial begin
    pclk = 1'b0;
    forever #5 pclk = ~pclk;
  end

  initial begin
    uart_clk = 1'b0;
    forever #20 uart_clk = ~uart_clk;
  end

  initial begin
    presetn    = 1'b0;
    uart_rst_n = 1'b0;
    #80;
    presetn    = 1'b1;
    uart_rst_n = 1'b1;
  end

  apb_if  apb_vif  (.pclk(pclk), .presetn(presetn));
  uart_if uart_vif (.uart_clk(uart_clk), .uart_rst_n(uart_rst_n));

  apb_uart #(
    .FIFO_ADDR_WIDTH(4)
  ) u_dut (
    .pclk       (pclk),
    .presetn    (presetn),
    .uart_clk   (uart_clk),
    .uart_rst_n (uart_rst_n),
    .psel       (apb_vif.psel),
    .penable    (apb_vif.penable),
    .pwrite     (apb_vif.pwrite),
    .paddr      (apb_vif.paddr),
    .pwdata     (apb_vif.pwdata),
    .prdata     (apb_vif.prdata),
    .pready     (apb_vif.pready),
    .pslverr    (apb_vif.pslverr),
    .rx_i       (uart_vif.rx_i),
    .tx_o       (uart_vif.tx_o),
    .irq_o      (irq_o)
  );

  apb_uart_sva u_apb_uart_sva (
    .pclk    (pclk),
    .presetn (presetn),
    .psel    (apb_vif.psel),
    .penable (apb_vif.penable),
    .pwrite  (apb_vif.pwrite),
    .paddr   (apb_vif.paddr),
    .pwdata  (apb_vif.pwdata),
    .pready  (apb_vif.pready),
    .pslverr (apb_vif.pslverr),
    .irq_o   (irq_o)
  );

  assign uart_vif.bit_tick = u_dut.baud_tick;

  initial begin
    apb_vif.idle_bus();
    uart_vif.idle_line();
  end

  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.apb.*", "vif", apb_vif);
    uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.uart.*", "vif", uart_vif);
    run_test();
  end

  initial begin
    #2ms;
    `uvm_fatal("TIMEOUT", "simulation timeout")
  end

endmodule
