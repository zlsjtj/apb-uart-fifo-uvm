`timescale 1ns/1ps
// Optional plain RTL contract check: does not execute or validate the UVM agent.
module tb_regblock_contract;
  reg pclk=0, presetn=0, psel=0, penable=0, pwrite=0;
  reg [7:0] paddr=0;
  reg [31:0] pwdata=0;
  wire [31:0] prdata;
  wire pready, pslverr;
  always #5 pclk=~pclk;
  regblock dut(.*);
  task transfer(input bit wr, input [7:0] addr, input [31:0] data,
                input bit err, input [31:0] expected);
    @(negedge pclk);
    psel=1; penable=0; pwrite=wr; paddr=addr; pwdata=data;
    @(negedge pclk); penable=1;
    @(posedge pclk);
    if (pready !== 1 || pslverr !== err) $fatal(1,"CONTRACT_RESPONSE addr=%h",addr);
    if (!wr && !err && prdata !== expected)
      $fatal(1,"CONTRACT_DATA addr=%h expected=%h got=%h",addr,expected,prdata);
    @(negedge pclk); psel=0; penable=0;
  endtask
  initial begin
    // Explicit edge avoids reliance on time-zero reset initialization semantics.
    #1 presetn=1;
    #1 presetn=0;
    repeat(3) @(negedge pclk);
    presetn=1;
    transfer(0,0,0,0,32'h52454731);
    transfer(0,4,0,0,32'h12345678);
    transfer(0,8,0,0,0);
    transfer(1,4,32'ha5a55a5a,0,0);
    transfer(0,4,0,0,32'ha5a55a5a);
    transfer(1,8,32'hffffffff,0,0);
    transfer(0,8,0,0,3);
    transfer(1,0,0,1,0);
    transfer(0,0,0,0,32'h52454731);
    transfer(0,12,0,1,0);
    transfer(1,12,32'hdeadbeef,1,0);
    transfer(0,4,0,0,32'ha5a55a5a);
    $display("RTL_CONTRACT_PASS: 12 accesses");
    $finish;
  end
  initial begin #10000; $fatal(1,"CONTRACT_TIMEOUT"); end
endmodule
