module apb_uart #(
  parameter int FIFO_ADDR_WIDTH = 4
) (
  input  logic pclk, presetn, uart_clk, uart_rst_n,
  input  logic psel, penable, pwrite,
  input  logic [7:0] paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic pready, pslverr,
  input  logic rx_i,
  output logic tx_o, irq_o
);
  import apb_uart_reg_pkg::*;

  logic [31:0] ctrl_reg, baud_reg;
  logic [31:0] prdata_response;
  logic pslverr_response;
  logic tx_push, rx_pop, tx_full, tx_empty, rx_full_uart, rx_empty, rx_empty_raw;
  logic [7:0] tx_fifo_rdata, tx_fifo_wdata, rx_fifo_rdata, rx_fifo_wdata;
  logic enable_uart, loopback_en, irq_en;

  logic [2:0] cfg_ctrl_hold, cfg_ctrl_value;
  logic [31:0] cfg_baud_hold, cfg_baud_value;
  logic cfg_req_tgl, cfg_ack_tgl, cfg_ack_pclk_q1, cfg_ack_pclk_q2;
  logic cfg_req_uart_q1, cfg_req_uart_q2, cfg_req_seen;
  logic cfg_uart_initialized, cfg_apply_uart, cfg_pending, cfg_write, cfg_busy;
  logic [2:0] ctrl_uart_cfg;
  logic [31:0] baud_uart_cfg;
  logic enable_uart_clk, loopback_uart_clk;

  logic [31:0] baud_cnt, baud_divisor;
  logic baud_tick, serial_bit_tick, tx_rd_en;
  logic tx_retired, tx_busy;
  logic [7:0] rx_data;
  logic rx_valid, rx_frame_err_uart, rx_wr_en;
  (* ASYNC_REG = "TRUE" *) logic rx_full_pclk_q1, rx_full_pclk_q2;
  (* ASYNC_REG = "TRUE" *) logic tx_empty_pclk_q1, tx_empty_pclk_q2;
  (* ASYNC_REG = "TRUE" *) logic rx_frame_err_pclk_q1, rx_frame_err_pclk_q2;
  logic pclk_rst_n, uart_clk_rst_n, fifo_async_rst_n;
  logic fifo_pclk_rst_n, fifo_uart_rst_n, cfg_uart_rst_n;

  assign pready = 1'b1;
`ifdef UART_MUTATE_APB_LATE_RESPONSE
  always_ff @(posedge pclk) begin
    prdata <= prdata_response;
    pslverr <= pslverr_response;
  end
`else
  assign prdata = prdata_response;
  assign pslverr = pslverr_response;
`endif
  assign enable_uart = ctrl_reg[UART_CTRL_ENABLE_BIT];
  assign loopback_en = ctrl_reg[UART_CTRL_LOOPBACK_BIT];
  assign irq_en = ctrl_reg[UART_CTRL_IRQ_EN_BIT];
  assign fifo_async_rst_n = presetn && uart_rst_n;
  assign cfg_uart_rst_n = fifo_uart_rst_n;
  assign enable_uart_clk = ctrl_uart_cfg[UART_CTRL_ENABLE_BIT];
  assign loopback_uart_clk = ctrl_uart_cfg[UART_CTRL_LOOPBACK_BIT];

`ifdef UART_MUTATE_IRQ_STUCK_HIGH
  assign irq_o = 1'b1;
`elsif UART_MUTATE_IRQ_STUCK_LOW
  assign irq_o = 1'b0;
`else
  assign irq_o = irq_en && !rx_empty;
`endif

`ifdef UART_MUTATE_RX_EMPTY_STUCK_HIGH
  assign rx_empty = 1'b1;
`else
  assign rx_empty = rx_empty_raw;
`endif

`ifdef UART_MUTATE_RX_LSB
  assign rx_fifo_wdata = rx_data ^ 8'h01;
`else
  assign rx_fifo_wdata = rx_data;
`endif

`ifdef UART_MUTATE_TX_LSB
  assign tx_fifo_wdata = pwdata[7:0] ^ 8'h01;
`else
  assign tx_fifo_wdata = pwdata[7:0];
`endif

  reset_sync u_pclk_reset_sync (
    .clk(pclk), .async_rst_n(presetn), .sync_rst_n(pclk_rst_n)
  );
  reset_sync u_uart_reset_sync (
    .clk(uart_clk), .async_rst_n(uart_rst_n), .sync_rst_n(uart_clk_rst_n)
  );
  reset_sync u_fifo_pclk_reset_sync (
    .clk(pclk), .async_rst_n(fifo_async_rst_n), .sync_rst_n(fifo_pclk_rst_n)
  );
  reset_sync u_fifo_uart_reset_sync (
    .clk(uart_clk), .async_rst_n(fifo_async_rst_n), .sync_rst_n(fifo_uart_rst_n)
  );

  apb_uart_regs u_regs (
    .pclk(pclk), .pclk_rst_n(pclk_rst_n), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
    .tx_full(tx_full), .tx_empty(tx_empty_pclk_q2), .rx_full(rx_full_pclk_q2),
    .rx_empty(rx_empty), .rx_fifo_rdata(rx_fifo_rdata),
    .rx_frame_err(rx_frame_err_pclk_q2), .irq(irq_o), .cfg_busy(cfg_busy), .tx_busy(tx_busy),
    .fifo_ready(fifo_pclk_rst_n),
    .prdata(prdata_response), .pslverr(pslverr_response), .ctrl_reg(ctrl_reg), .baud_reg(baud_reg),
    .tx_push(tx_push), .rx_pop(rx_pop), .cfg_write(cfg_write),
    .cfg_ctrl_value(cfg_ctrl_value), .cfg_baud_value(cfg_baud_value)
  );

  apb_uart_cfg_cdc u_cfg_cdc (
    .pclk(pclk), .pclk_rst_n(fifo_pclk_rst_n), .uart_clk(uart_clk),
    .uart_rst_n(cfg_uart_rst_n), .cfg_write(cfg_write),
    .cfg_ctrl_value(cfg_ctrl_value), .cfg_baud_value(cfg_baud_value),
    .apb_ctrl_current(ctrl_reg[2:0]), .apb_baud_current(baud_reg),
    .cfg_ctrl_hold(cfg_ctrl_hold), .cfg_baud_hold(cfg_baud_hold),
    .cfg_req_tgl(cfg_req_tgl), .cfg_ack_tgl(cfg_ack_tgl),
    .cfg_ack_pclk_q1(cfg_ack_pclk_q1), .cfg_ack_pclk_q2(cfg_ack_pclk_q2),
    .cfg_req_uart_q1(cfg_req_uart_q1), .cfg_req_uart_q2(cfg_req_uart_q2),
    .cfg_req_seen(cfg_req_seen), .cfg_uart_initialized(cfg_uart_initialized),
    .cfg_apply_uart(cfg_apply_uart), .cfg_pending(cfg_pending), .cfg_busy(cfg_busy),
    .ctrl_uart_cfg(ctrl_uart_cfg), .baud_uart_cfg(baud_uart_cfg)
  );

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      rx_full_pclk_q1 <= 1'b0;
      tx_empty_pclk_q1 <= 1'b1;
      tx_empty_pclk_q2 <= 1'b1;
      rx_full_pclk_q2 <= 1'b0;
      rx_frame_err_pclk_q1 <= 1'b0;
      rx_frame_err_pclk_q2 <= 1'b0;
    end else begin
      rx_full_pclk_q1 <= rx_full_uart;
      tx_empty_pclk_q1 <= tx_empty;
      tx_empty_pclk_q2 <= tx_empty_pclk_q1;
      rx_full_pclk_q2 <= rx_full_pclk_q1;
      rx_frame_err_pclk_q1 <= rx_frame_err_uart;
      rx_frame_err_pclk_q2 <= rx_frame_err_pclk_q1;
    end
  end

  async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_tx_fifo (
    .wr_clk(pclk), .wr_rst_n(fifo_pclk_rst_n), .wr_en(tx_push),
    .wr_data(tx_fifo_wdata), .wr_full(tx_full), .rd_clk(uart_clk),
    .rd_rst_n(fifo_uart_rst_n), .rd_en(tx_rd_en),
    .rd_data(tx_fifo_rdata), .rd_empty(tx_empty)
  );
  // synthesis translate_off
  async_fifo_sva #(.DATA_WIDTH(8), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_tx_fifo_sva (
    .wr_clk(pclk), .wr_rst_n(fifo_pclk_rst_n), .wr_en(tx_push),
    .wr_data(tx_fifo_wdata), .wr_full(tx_full), .rd_clk(uart_clk),
    .rd_rst_n(fifo_uart_rst_n), .rd_en(tx_rd_en),
    .rd_data(tx_fifo_rdata), .rd_empty(tx_empty)
  );
  // synthesis translate_on

  tx_completion_cdc #(.ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_tx_completion (
    .pclk(pclk), .pclk_rst_n(fifo_pclk_rst_n), .accepted_i(tx_push),
    .uart_clk(uart_clk), .uart_rst_n(fifo_uart_rst_n), .retired_i(tx_retired),
    .busy_o(tx_busy)
  );

  apb_uart_serial_core u_serial_core (
    .uart_clk(uart_clk), .uart_rst_n(fifo_uart_rst_n),
    .enable(enable_uart_clk), .loopback(loopback_uart_clk),
    .baud_value(baud_uart_cfg), .rx_i(rx_i),
    .tx_fifo_rdata(tx_fifo_rdata), .tx_empty(tx_empty), .rx_full(rx_full_uart),
    .tx_o(tx_o), .tx_rd_en(tx_rd_en), .tx_retired(tx_retired), .rx_data(rx_data), .rx_valid(rx_valid),
    .rx_frame_err(rx_frame_err_uart), .baud_count(baud_cnt),
    .baud_divisor(baud_divisor), .baud_tick(baud_tick),
    .serial_bit_tick(serial_bit_tick)
  );

  assign rx_wr_en = rx_valid && !rx_full_uart;

  async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_rx_fifo (
    .wr_clk(uart_clk), .wr_rst_n(fifo_uart_rst_n), .wr_en(rx_wr_en),
    .wr_data(rx_fifo_wdata), .wr_full(rx_full_uart), .rd_clk(pclk),
    .rd_rst_n(fifo_pclk_rst_n), .rd_en(rx_pop),
    .rd_data(rx_fifo_rdata), .rd_empty(rx_empty_raw)
  );
  // synthesis translate_off
  async_fifo_sva #(.DATA_WIDTH(8), .ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_rx_fifo_sva (
    .wr_clk(uart_clk), .wr_rst_n(fifo_uart_rst_n), .wr_en(rx_wr_en),
    .wr_data(rx_fifo_wdata), .wr_full(rx_full_uart), .rd_clk(pclk),
    .rd_rst_n(fifo_pclk_rst_n), .rd_en(rx_pop),
    .rd_data(rx_fifo_rdata), .rd_empty(rx_empty_raw)
  );
  // synthesis translate_on
endmodule
