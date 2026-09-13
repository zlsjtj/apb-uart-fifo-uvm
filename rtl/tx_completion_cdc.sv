// Count accepted writes locally and retirements after a complete stop bit in
// the UART domain. A delayed idle level alone would falsely report idle just
// after an APB write. Use four times FIFO depth as the modulo capacity to also
// cover the active frame and the registered retirement pipeline at depth two.
module tx_completion_cdc #(
  parameter int ADDR_WIDTH = 4
) (
  input logic pclk, pclk_rst_n, accepted_i,
  input logic uart_clk, uart_rst_n, retired_i,
  output logic busy_o
);
  localparam int COUNT_WIDTH=ADDR_WIDTH+2;
  logic [COUNT_WIDTH-1:0] issued;
  logic [COUNT_WIDTH-1:0] retired_bin, retired_gray;
  logic [COUNT_WIDTH-1:0] retired_next, retired_pclk;
  (* ASYNC_REG = "TRUE" *) logic [COUNT_WIDTH-1:0] retired_q1, retired_q2;

  assign retired_next = retired_bin + 1'b1;
  always_comb begin
    retired_pclk[COUNT_WIDTH-1] = retired_q2[COUNT_WIDTH-1];
    for (int i = COUNT_WIDTH-2; i >= 0; i--)
      retired_pclk[i] = retired_pclk[i+1] ^ retired_q2[i];
  end
  assign busy_o = (issued != retired_pclk);

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      issued <= '0;
      retired_q1 <= '0;
      retired_q2 <= '0;
    end else begin
      if (accepted_i) issued <= issued + 1'b1;
      retired_q1 <= retired_gray;
      retired_q2 <= retired_q1;
    end
  end

  always_ff @(posedge uart_clk or negedge uart_rst_n) begin
    if (!uart_rst_n) begin
      retired_bin <= '0;
      retired_gray <= '0;
    end else if (retired_i) begin
      retired_bin <= retired_next;
      retired_gray <= (retired_next >> 1) ^ retired_next;
    end
  end

  // synthesis translate_off
  retired_gray_single_step:
    assert property (@(posedge uart_clk) disable iff (!uart_rst_n)
      $past(uart_rst_n) |-> $onehot0(retired_gray ^ $past(retired_gray)));
  // synthesis translate_on
endmodule
