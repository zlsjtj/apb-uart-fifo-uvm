module reset_sync #(
  parameter int STAGES = 2
) (
  input  logic clk,
  input  logic async_rst_n,
  output logic sync_rst_n
);

  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_pipe;

  initial begin
    if (STAGES < 2) begin
      $error("reset_sync requires STAGES >= 2");
    end
  end

  always_ff @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n) begin
      sync_pipe <= '0;
    end else begin
      sync_pipe <= {sync_pipe[STAGES-2:0], 1'b1};
    end
  end

  assign sync_rst_n = sync_pipe[STAGES-1];

endmodule
