module probe;
  timeunit 1ns;
  timeprecision 1ps;

  bit clk = 0, rst_n = 0, enable = 0;
  wire ready, tx, retired;
  int changes = 0;

  always #5 clk = ~clk;
  uart_tx dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .bit_tick_i(1'b1),
    .data_i(8'h55), .valid_i(1'b1), .ready_o(ready),
    .tx_o(tx), .retired_o(retired)
  );

  always @(ready) if (!$isunknown(ready)) changes++;

  initial begin
    #1 rst_n = 1;
    #1 rst_n = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;
    enable = 1;
    repeat (60) @(negedge clk);
    if (changes < 10) $fatal(1, "READY_DID_NOT_TOGGLE");
    $display("PROBE_PASS changes=%0d", changes);
    $finish;
  end
endmodule
