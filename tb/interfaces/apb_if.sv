interface apb_if (
  input logic pclk,
  input logic presetn
);
  timeunit 1ns;
  timeprecision 1ps;

  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [7:0]  paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  clocking drv_cb @(posedge pclk);
    default input #1step output #1ns;
    output psel;
    output penable;
    output pwrite;
    output paddr;
    output pwdata;
    input  prdata;
    input  pready;
    input  pslverr;
  endclocking

  clocking mon_cb @(posedge pclk);
    default input #1step output #1ns;
    input psel;
    input penable;
    input pwrite;
    input paddr;
    input pwdata;
    input prdata;
    input pready;
    input pslverr;
  endclocking

  task automatic idle_bus();
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
    paddr   <= '0;
    pwdata  <= '0;
  endtask

endinterface
