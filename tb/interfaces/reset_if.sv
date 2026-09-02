interface reset_if (
  input logic pclk,
  input logic uart_clk
);
  timeunit 1ns;
  timeprecision 1ps;

  logic presetn;
  logic uart_rst_n;

  initial begin
    presetn    = 1'b0;
    uart_rst_n = 1'b0;
    #80ns;
    presetn    = 1'b1;
    uart_rst_n = 1'b1;
  end

  task automatic pulse_apb_reset(input int unsigned cycles = 3);
    @(negedge pclk);
    presetn = 1'b0;
    repeat (cycles) @(posedge pclk);
    @(negedge pclk);
    presetn = 1'b1;
    // Both FIFO domains are released through two-stage reset synchronizers.
    fork
      repeat (3) @(posedge pclk);
      repeat (3) @(posedge uart_clk);
    join
  endtask

  task automatic pulse_uart_reset(input int unsigned cycles = 3);
    @(negedge uart_clk);
    uart_rst_n = 1'b0;
    repeat (cycles) @(posedge uart_clk);
    @(negedge uart_clk);
    uart_rst_n = 1'b1;
    fork
      repeat (3) @(posedge pclk);
      repeat (3) @(posedge uart_clk);
    join
  endtask

  task automatic pulse_both(input int unsigned apb_cycles = 3,
                            input int unsigned uart_cycles = 3);
    @(negedge pclk);
    presetn    = 1'b0;
    uart_rst_n = 1'b0;
    fork
      begin
        repeat (apb_cycles) @(posedge pclk);
        @(negedge pclk);
        presetn = 1'b1;
      end
      begin
        repeat (uart_cycles) @(posedge uart_clk);
        @(negedge uart_clk);
        uart_rst_n = 1'b1;
      end
    join
    fork
      repeat (3) @(posedge pclk);
      repeat (3) @(posedge uart_clk);
    join
  endtask

endinterface
