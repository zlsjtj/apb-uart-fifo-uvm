module uart_baud_gen (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic [31:0] baud_value,
  output logic [31:0] count,
  output logic [31:0] divisor,
  output logic        tick
);
  assign divisor = (baud_value == 0) ? 32'd1 : baud_value;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 32'd0;
      tick  <= 1'b0;
    end else begin
      tick <= 1'b0;
      if (!enable) begin
        count <= 32'd0;
      end else if (count >= (divisor - 1)) begin
        count <= 32'd0;
        tick  <= 1'b1;
      end else begin
        count <= count + 32'd1;
      end
    end
  end
endmodule
