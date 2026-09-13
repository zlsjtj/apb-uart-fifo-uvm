module async_fifo #(
  parameter int DATA_WIDTH = 8,
  parameter int ADDR_WIDTH = 4
) (
  input  logic                  wr_clk,
  input  logic                  wr_rst_n,
  input  logic                  wr_en,
  input  logic [DATA_WIDTH-1:0] wr_data,
  output logic                  wr_full,

  input  logic                  rd_clk,
  input  logic                  rd_rst_n,
  input  logic                  rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic                  rd_empty
);

  localparam int PTR_WIDTH = ADDR_WIDTH + 1;
  localparam int DEPTH     = 1 << ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_WIDTH-1:0] wbin,  wbin_next;
  logic [PTR_WIDTH-1:0] rbin,  rbin_next;
  logic [PTR_WIDTH-1:0] wgray, wgray_next;
  logic [PTR_WIDTH-1:0] rgray, rgray_next;
  logic wr_full_q;
  localparam logic [PTR_WIDTH-1:0] FULL_XOR_MASK =
    ({{(PTR_WIDTH-1){1'b0}}, 1'b1} << (PTR_WIDTH-1)) |
    ({{(PTR_WIDTH-1){1'b0}}, 1'b1} << (PTR_WIDTH-2));

  (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] rgray_wclk_q1, rgray_wclk_q2;
  (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] wgray_rclk_q1, wgray_rclk_q2;

  function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
    return (bin >> 1) ^ bin;
  endfunction

  assign wbin_next  = wbin + (wr_en && !wr_full);
  assign rbin_next  = rbin + (rd_en && !rd_empty);
  assign wgray_next = bin2gray(wbin_next);
  assign rgray_next = bin2gray(rbin_next);

`ifdef UART_MUTATE_FIFO_FULL_STUCK_LOW
  assign wr_full = 1'b0;
`else
  assign wr_full = wr_full_q;
`endif
  assign rd_data  = mem[rbin[ADDR_WIDTH-1:0]];

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wbin  <= '0;
      wgray <= '0;
      wr_full_q <= 1'b0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
      wr_full_q <= (wgray_next == (rgray_wclk_q2 ^ FULL_XOR_MASK));
    end
  end

  // Resetting the pointers makes all old entries unreachable, so the storage
  // array itself needs no reset. Keeping RAM writes in a reset-free process
  // also lets FPGA synthesis infer memory instead of expanding every bit into
  // an asynchronously reset flip-flop.
  always_ff @(posedge wr_clk) begin
    if (wr_rst_n && wr_en && !wr_full) begin
      mem[wbin[ADDR_WIDTH-1:0]] <= wr_data;
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rbin  <= '0;
      rgray <= '0;
      rd_empty <= 1'b1;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
      rd_empty <= (rgray_next == wgray_rclk_q2);
    end
  end

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rgray_wclk_q1 <= '0;
      rgray_wclk_q2 <= '0;
    end else begin
      rgray_wclk_q1 <= rgray;
      rgray_wclk_q2 <= rgray_wclk_q1;
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wgray_rclk_q1 <= '0;
      wgray_rclk_q2 <= '0;
    end else begin
      wgray_rclk_q1 <= wgray;
      wgray_rclk_q2 <= wgray_rclk_q1;
    end
  end

  // synthesis translate_off
  write_gray_single_step:
    assert property (@(posedge wr_clk) disable iff (!wr_rst_n)
      $past(wr_rst_n) |-> $onehot0(wgray ^ $past(wgray)));
  read_gray_single_step:
    assert property (@(posedge rd_clk) disable iff (!rd_rst_n)
      $past(rd_rst_n) |-> $onehot0(rgray ^ $past(rgray)));
  write_pointer_holds_without_accept:
    assert property (@(posedge wr_clk) disable iff (!wr_rst_n)
      (!wr_en || wr_full) |=> $stable(wbin));
  read_pointer_holds_without_accept:
    assert property (@(posedge rd_clk) disable iff (!rd_rst_n)
      (!rd_en || rd_empty) |=> $stable(rbin));
  // synthesis translate_on
endmodule
