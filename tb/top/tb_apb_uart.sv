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
  integer pclk_half_ns;
  integer uart_half_ns;
  integer pclk_phase_ns;
  integer uart_phase_ns;
  localparam int FIFO_ADDR_WIDTH = 4;

  initial begin
    pclk_half_ns = 5;
    pclk_phase_ns = 0;
    void'($value$plusargs("PCLK_HALF_NS=%d", pclk_half_ns));
    void'($value$plusargs("PCLK_PHASE_NS=%d", pclk_phase_ns));
    pclk = 1'b0;
    #(pclk_phase_ns);
    forever #(pclk_half_ns) pclk = ~pclk;
  end

  initial begin
    uart_half_ns = 20;
    uart_phase_ns = 0;
    void'($value$plusargs("UART_HALF_NS=%d", uart_half_ns));
    void'($value$plusargs("UART_PHASE_NS=%d", uart_phase_ns));
    uart_clk = 1'b0;
    #(uart_phase_ns);
    forever #(uart_half_ns) uart_clk = ~uart_clk;
  end

  reset_if reset_vif (.pclk(pclk), .uart_clk(uart_clk));
  assign presetn    = reset_vif.presetn;
  assign uart_rst_n = reset_vif.uart_rst_n;

  apb_if  apb_vif  (.pclk(pclk), .presetn(presetn));
  uart_if uart_vif (.uart_clk(uart_clk), .uart_rst_n(uart_rst_n));

  apb_uart #(
    .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
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
    .uart_clk(uart_clk),
    .uart_rst_n(uart_rst_n),
    .pclk_rst_n(u_dut.pclk_rst_n),
    .uart_clk_rst_n(u_dut.uart_clk_rst_n),
    .fifo_async_rst_n(u_dut.fifo_async_rst_n),
    .fifo_pclk_rst_n(u_dut.fifo_pclk_rst_n),
    .fifo_uart_rst_n(u_dut.fifo_uart_rst_n),
    .psel    (apb_vif.psel),
    .penable (apb_vif.penable),
    .pwrite  (apb_vif.pwrite),
    .paddr   (apb_vif.paddr),
    .pwdata  (apb_vif.pwdata),
    .pready  (apb_vif.pready),
    .pslverr (apb_vif.pslverr),
    .cfg_busy(u_dut.cfg_busy),
    .cfg_req_tgl(u_dut.cfg_req_tgl),
    .cfg_ack_pclk_q2(u_dut.cfg_ack_pclk_q2),
    .cfg_uart_initialized(u_dut.cfg_uart_initialized),
    .cfg_apply_uart(u_dut.cfg_apply_uart),
    .ctrl_uart_cfg(u_dut.ctrl_uart_cfg),
    .baud_uart_cfg(u_dut.baud_uart_cfg),
    .enable_uart(u_dut.enable_uart),
    .irq_en  (u_dut.irq_en),
    .tx_full (u_dut.tx_full),
    .tx_push (u_dut.tx_push),
    .rx_full (u_dut.rx_full_uart),
    .rx_full_pclk(u_dut.rx_full_pclk_q2),
    .rx_empty(u_dut.rx_empty),
    .rx_pop  (u_dut.rx_pop),
    .rx_frame_err(u_dut.rx_frame_err_uart),
    .rx_frame_err_pclk(u_dut.rx_frame_err_pclk_q2),
    .rx_wr_en(u_dut.rx_wr_en),
    .irq_o   (irq_o)
  );

  assign uart_vif.bit_tick = u_dut.baud_tick;
  assign uart_vif.ctrl_uart_cfg = u_dut.ctrl_uart_cfg;
  assign uart_vif.baud_uart_cfg = u_dut.baud_uart_cfg;
  assign uart_vif.cfg_apply = u_dut.cfg_apply_uart;

  initial begin
    apb_vif.idle_bus();
    uart_vif.idle_line();
  end

  initial begin
    #1ns;
    $display("[TB_CLOCKS] pclk_half=%0dns pclk_phase=%0dns uart_half=%0dns uart_phase=%0dns",
             pclk_half_ns, pclk_phase_ns, uart_half_ns, uart_phase_ns);
  end

  initial begin
    uart_env_cfg env_cfg;
    #0;
    env_cfg = uart_env_cfg::type_id::create("env_cfg");
    env_cfg.fifo_addr_width = FIFO_ADDR_WIDTH;
    env_cfg.pclk_half_ns = pclk_half_ns;
    env_cfg.uart_half_ns = uart_half_ns;
    env_cfg.pclk_phase_ns = pclk_phase_ns;
    env_cfg.uart_phase_ns = uart_phase_ns;
    uvm_config_db#(uart_env_cfg)::set(null, "uvm_test_top.env*", "env_cfg", env_cfg);
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.apb.*", "vif", apb_vif);
    uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.uart.*", "vif", uart_vif);
    uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top", "timing_vif", uart_vif);
    uvm_config_db#(virtual reset_if)::set(null, "uvm_test_top*", "reset_vif", reset_vif);
    run_test();
  end

  initial begin
    #2ms;
    `uvm_fatal("TIMEOUT", "simulation timeout")
  end

endmodule
