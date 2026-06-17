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

  logic [PTR_WIDTH-1:0] rgray_wclk_q1, rgray_wclk_q2;
  logic [PTR_WIDTH-1:0] wgray_rclk_q1, wgray_rclk_q2;

  function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
    return (bin >> 1) ^ bin;
  endfunction

  assign wbin_next  = wbin + (wr_en && !wr_full);
  assign rbin_next  = rbin + (rd_en && !rd_empty);
  assign wgray_next = bin2gray(wbin_next);
  assign rgray_next = bin2gray(rbin_next);

  assign wr_full = (wgray == {
                    ~rgray_wclk_q2[PTR_WIDTH-1:PTR_WIDTH-2],
                     rgray_wclk_q2[PTR_WIDTH-3:0]
                  });
  assign rd_empty = (rgray == wgray_rclk_q2);
  assign rd_data  = mem[rbin[ADDR_WIDTH-1:0]];

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wbin  <= '0;
      wgray <= '0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
      if (wr_en && !wr_full) begin
        mem[wbin[ADDR_WIDTH-1:0]] <= wr_data;
      end
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rbin  <= '0;
      rgray <= '0;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
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

endmodule
