module apb_uart_sva (
  input logic        pclk,
  input logic        presetn,
  input logic        psel,
  input logic        penable,
  input logic        pwrite,
  input logic [7:0]  paddr,
  input logic [31:0] pwdata,
  input logic        pready,
  input logic        pslverr,
  input logic        irq_o
);

  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_BAUD   = 8'h08;
  localparam logic [7:0] ADDR_TXDATA = 8'h0c;
  localparam logic [7:0] ADDR_RXDATA = 8'h10;

  logic legal_addr;
  assign legal_addr = (paddr == ADDR_CTRL)   ||
                      (paddr == ADDR_STATUS) ||
                      (paddr == ADDR_BAUD)   ||
                      (paddr == ADDR_TXDATA) ||
                      (paddr == ADDR_RXDATA);

  apb_setup_to_access:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && !penable) |=> (psel && penable));

  apb_access_has_ready:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && penable) |-> pready);

  apb_addr_stable_in_access:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && !penable) |=> $stable(paddr));

  invalid_addr_reports_error:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && penable && !legal_addr) |=> pslverr);

  status_write_reports_error:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && penable && pwrite && paddr == ADDR_STATUS) |=> pslverr);

  baud_div_not_zero_after_write:
    assert property (@(posedge pclk) disable iff (!presetn)
      (psel && penable && pwrite && paddr == ADDR_BAUD && pwdata == 0) |=> !pslverr);

  irq_is_known:
    assert property (@(posedge pclk) disable iff (!presetn)
      !$isunknown(irq_o));

endmodule
