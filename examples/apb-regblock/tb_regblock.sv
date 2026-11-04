module tb_regblock;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import regblock_pkg::*;
  bit pclk = 0;
  bit presetn = 0;
  always #5 pclk = ~pclk;
  apb_if bus(pclk, presetn);
  regblock dut(.pclk(pclk), .presetn(presetn), .psel(bus.psel),
    .penable(bus.penable), .pwrite(bus.pwrite), .paddr(bus.paddr),
    .pwdata(bus.pwdata), .prdata(bus.prdata), .pready(bus.pready),
    .pslverr(bus.pslverr));
  initial begin
    repeat (4) @(negedge pclk);
    presetn = 1;
  end
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", bus);
    run_test("regblock_test");
  end
  initial begin
    #10000;
    $fatal(1, "REGBLOCK_TIMEOUT");
  end
endmodule
