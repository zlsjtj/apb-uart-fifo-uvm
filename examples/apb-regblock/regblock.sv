// A deliberately small, zero-wait-state APB register peripheral.
module regblock (
  input wire pclk, presetn, psel, penable, pwrite,
  input wire [7:0] paddr,
  input wire [31:0] pwdata,
  output reg [31:0] prdata,
  output wire pready,
  output reg pslverr
);
  reg [31:0] scratch;
  reg [31:0] control;
  assign pready = 1'b1;
  always @* begin
    prdata = 32'b0;
    pslverr = 1'b0;
    case (paddr)
      8'h00: prdata = 32'h52454731; // ID, read-only
      8'h04: prdata = scratch;
      8'h08: prdata = control;
      default: pslverr = 1'b1;
    endcase
    if (pwrite && paddr == 8'h00) pslverr = 1'b1;
  end
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      scratch <= 32'h12345678;
      control <= 32'b0;
    end else if (psel && penable && pwrite && !pslverr) begin
      case (paddr)
        8'h04: begin
`ifdef REGBLOCK_INJECT_FAULT
          scratch <= pwdata ^ 32'h1;
`else
          scratch <= pwdata;
`endif
        end
        8'h08: control <= pwdata & 32'h3;
        default: ;
      endcase
    end
  end
endmodule
