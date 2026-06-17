module async_fifo_sva #(
  parameter int DATA_WIDTH = 8,
  parameter int ADDR_WIDTH = 4
) (
  input logic                  wr_clk,
  input logic                  wr_rst_n,
  input logic                  wr_en,
  input logic [DATA_WIDTH-1:0] wr_data,
  input logic                  wr_full,
  input logic                  rd_clk,
  input logic                  rd_rst_n,
  input logic                  rd_en,
  input logic [DATA_WIDTH-1:0] rd_data,
  input logic                  rd_empty
);

  no_overflow_write:
    assert property (@(posedge wr_clk) disable iff (!wr_rst_n)
      !(wr_en && wr_full));

  no_underflow_read:
    assert property (@(posedge rd_clk) disable iff (!rd_rst_n)
      !(rd_en && rd_empty));

  write_side_flags_known:
    assert property (@(posedge wr_clk) disable iff (!wr_rst_n)
      !$isunknown(wr_full));

  read_side_flags_known:
    assert property (@(posedge rd_clk) disable iff (!rd_rst_n)
      !$isunknown(rd_empty));

  read_data_known_when_accepted:
    assert property (@(posedge rd_clk) disable iff (!rd_rst_n)
      (rd_en && !rd_empty) |-> !$isunknown(rd_data));

  write_data_known_when_accepted:
    assert property (@(posedge wr_clk) disable iff (!wr_rst_n)
      (wr_en && !wr_full) |-> !$isunknown(wr_data));

endmodule

bind async_fifo async_fifo_sva #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)
) u_async_fifo_sva (
  .wr_clk   (wr_clk),
  .wr_rst_n (wr_rst_n),
  .wr_en    (wr_en),
  .wr_data  (wr_data),
  .wr_full  (wr_full),
  .rd_clk   (rd_clk),
  .rd_rst_n (rd_rst_n),
  .rd_en    (rd_en),
  .rd_data  (rd_data),
  .rd_empty (rd_empty)
);
