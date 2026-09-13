`timescale 1ns/1ps
module apb_contract_tb;
  import apb_uart_reg_pkg::*;
  parameter int FIFO_ADDR_WIDTH = 4;
  logic pclk = 0, uart_clk = 0;
  always #5 pclk = ~pclk;
  always #7 uart_clk = ~uart_clk;
  logic presetn = 0, uart_rst_n = 0;
  logic psel = 0, penable = 0, pwrite = 0;
  logic [7:0] paddr = 0;
  logic [31:0] pwdata = 0, prdata;
  logic pready, pslverr, tx_o, irq_o;
  bit [31:0] value;
  int checks;
  apb_uart #(.FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)) dut (.*,.rx_i(1'b1));

  // The caller is on a falling edge. Keep PSEL asserted between calls:
  // each transfer has exactly one SETUP and one ACCESS cycle, no idle gap.
  task access(bit wr, bit [7:0] addr, bit [31:0] data, bit error_expected,
              output bit [31:0] result);
    psel = 1; penable = 0; pwrite = wr; paddr = addr; pwdata = data;
    @(negedge pclk); penable = 1;
    @(posedge pclk);
    if (pready !== 1 || pslverr !== error_expected)
      $fatal(1, "APB_EDGE_RESPONSE addr=%h ready=%b error=%b expected=%b",
             addr, pready, pslverr, error_expected);
    result = prdata;
    checks++;
    @(negedge pclk); penable = 0;
  endtask

  task expect_read(bit [7:0] addr, bit [31:0] expected);
    access(0, addr, 0, 0, value);
    if (value !== expected) $fatal(1, "APB_EDGE_DATA addr=%h got=%h expected=%h", addr, value, expected);
  endtask

  task settle_config();
    for (int n=0; n<256; n++) begin
      access(0, UART_ADDR_STATUS, 0, 0, value);
      if (!value[UART_STATUS_CFG_BUSY_BIT]) return;
    end
    $fatal(1, "APB_CFG_TIMEOUT");
  endtask

  task settle_tx();
    for (int n=0; n<4096; n++) begin
      access(0, UART_ADDR_STATUS, 0, 0, value);
      if (!value[UART_STATUS_TX_BUSY_BIT] && !value[UART_STATUS_CFG_BUSY_BIT]) return;
    end
    $fatal(1,"APB_TX_BUSY_TIMEOUT");
  endtask

  task abort_frame(bit during_stop);
    settle_tx();
    access(1, UART_ADDR_BAUD, 20, 0, value);
    access(1, UART_ADDR_CTRL, 1, 0, value);
    settle_config();
    fork
      access(1, UART_ADDR_TXDATA, 8'h55, 0, value);
      begin
        @(negedge tx_o);
        #((during_stop ? 9 : 2)*20*14+20);
      end
    join
    @(negedge pclk);
    // Raw disable is an explicit abort, not normal safe reconfiguration.
    access(1, UART_ADDR_CTRL, 0, 0, value);
    settle_config();
    settle_tx();
    if (tx_o !== 1'b1) $fatal(1,"APB_TX_ABORT_IDLE");
  endtask

  initial begin
    repeat (4) @(negedge pclk);
    presetn = 1; uart_rst_n = 1;
    repeat (8) @(negedge pclk);
    if ($test$plusargs("ELAB_ONLY")) begin
      $display("APB_CONTRACT_PASS elaboration_only width=%0d", FIFO_ADDR_WIDTH);
      $finish;
    end
    expect_read(UART_ADDR_BAUD, UART_BAUD_RESET);
    expect_read(UART_ADDR_CTRL, UART_CTRL_RESET);
    access(0, 8'hfc, 0, 1, value);
    access(1, UART_ADDR_STATUS, 1, 1, value);
    access(0, UART_ADDR_TXDATA, 0, 1, value);
    access(0, UART_ADDR_RXDATA, 0, 1, value);
    access(1, UART_ADDR_RXDATA, 0, 1, value);
    access(1, UART_ADDR_TXDATA, 8'h55, 1, value);
    access(1, UART_ADDR_BAUD, 1, 0, value);
    expect_read(UART_ADDR_BAUD, 1);
    access(1, UART_ADDR_CTRL, 7, 0, value);
    settle_config();
    // Exercise wraparound repeatedly, including a depth-two FIFO.
    for (int i=0; i<2*(1<<FIFO_ADDR_WIDTH)+3; i++) begin
      access(1, UART_ADDR_TXDATA, (i*17)&255, 0, value);
      for (int n=0; n<256; n++) begin
        access(0, UART_ADDR_STATUS, 0, 0, value);
        if (!value[UART_STATUS_RX_EMPTY_BIT]) break;
        if (n==255) $fatal(1, "APB_RX_TIMEOUT");
      end
      expect_read(UART_ADDR_RXDATA, (i*17)&255);
      access(0, UART_ADDR_RXDATA, 0, 1, value);
    end
    abort_frame(0);
    abort_frame(1);
    // The APB register bank stays alive during UART-only reset, but its FIFO
    // accesses must be rejected until the shared FIFO epoch is released.
    uart_rst_n=0;
    #1ps;
    access(1, UART_ADDR_TXDATA, 8'haa, 1, value);
    access(0, UART_ADDR_RXDATA, 0, 1, value);
    access(1, UART_ADDR_BAUD, 3, 0, value);
    uart_rst_n=1;
    settle_config();
    expect_read(UART_ADDR_BAUD, 3);
    psel = 0;
    $display("APB_CONTRACT_PASS depth=%0d checks=%0d", 1<<FIFO_ADDR_WIDTH, checks);
    $finish;
  end
  initial begin #100us; $fatal(1, "APB_CONTRACT_TIMEOUT"); end
endmodule
