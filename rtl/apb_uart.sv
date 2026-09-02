module apb_uart #(
  parameter int FIFO_ADDR_WIDTH = 4
) (
  input  logic        pclk,
  input  logic        presetn,
  input  logic        uart_clk,
  input  logic        uart_rst_n,

  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [7:0]  paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,

  input  logic        rx_i,
  output logic        tx_o,
  output logic        irq_o
);

  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_BAUD   = 8'h08;
  localparam logic [7:0] ADDR_TXDATA = 8'h0c;
  localparam logic [7:0] ADDR_RXDATA = 8'h10;

  logic [31:0] ctrl_reg;
  logic [31:0] baud_reg;

  logic        apb_access;
  logic        tx_push;
  logic        rx_pop;
  logic        tx_full;
  logic        tx_empty;
  logic        rx_full_uart;
  logic        rx_empty;
  logic [7:0]  tx_fifo_rdata;
  logic [7:0]  tx_fifo_wdata;
  logic [7:0]  rx_fifo_rdata;

  logic        enable_uart;
  logic        loopback_en;
  logic        irq_en;

  // CTRL and BAUD are transferred together through a one-entry mailbox.
  // The payload is held stable until the UART domain acknowledges the request.
  logic [2:0]  cfg_ctrl_hold;
  logic [31:0] cfg_baud_hold;
  logic        cfg_req_tgl;
  logic        cfg_ack_tgl;
  (* ASYNC_REG = "TRUE" *) logic cfg_ack_pclk_q1, cfg_ack_pclk_q2;
  (* ASYNC_REG = "TRUE" *) logic cfg_req_uart_q1, cfg_req_uart_q2;
  logic        cfg_req_seen;
  logic        cfg_uart_initialized;
  logic        cfg_pending;
  logic        cfg_write;
  logic        cfg_busy;
  logic [2:0]  ctrl_uart_cfg;
  logic        enable_uart_clk;
  logic        loopback_uart_clk;
  logic [31:0] baud_uart_cfg;
  logic [31:0] baud_cnt;
  logic [31:0] baud_divisor;
  logic        baud_tick;

  logic        tx_ready;
  logic        tx_rd_en;
  logic        serial_rx;
  logic [7:0]  rx_data;
  logic        rx_valid;
  logic        rx_frame_err_uart;
  (* ASYNC_REG = "TRUE" *) logic rx_full_pclk_q1, rx_full_pclk_q2;
  (* ASYNC_REG = "TRUE" *) logic rx_frame_err_pclk_q1, rx_frame_err_pclk_q2;
  logic        rx_wr_en;
  logic        pclk_rst_n;
  logic        uart_clk_rst_n;
  logic        fifo_async_rst_n;
  logic        fifo_pclk_rst_n;
  logic        fifo_uart_rst_n;
  logic        cfg_uart_rst_n;

  assign apb_access  = psel && penable;
  assign pready      = 1'b1;
  assign enable_uart = ctrl_reg[0];
  assign loopback_en = ctrl_reg[1];
  assign irq_en      = ctrl_reg[2];
  assign irq_o       = irq_en && !rx_empty;
  assign fifo_async_rst_n = presetn && uart_rst_n;
  assign cfg_write   = apb_access && pwrite &&
                       ((paddr == ADDR_CTRL) || (paddr == ADDR_BAUD));
  assign cfg_busy    = (cfg_req_tgl != cfg_ack_pclk_q2);

`ifdef UART_MUTATE_TX_LSB
  assign tx_fifo_wdata = pwdata[7:0] ^ 8'h01;
`else
  assign tx_fifo_wdata = pwdata[7:0];
`endif

  assign tx_push = apb_access && pwrite && (paddr == ADDR_TXDATA) &&
                   enable_uart && !tx_full;
  assign rx_pop  = apb_access && !pwrite && (paddr == ADDR_RXDATA) &&
                   !rx_empty;

  reset_sync u_pclk_reset_sync (
    .clk         (pclk),
    .async_rst_n (presetn),
    .sync_rst_n  (pclk_rst_n)
  );

  reset_sync u_uart_reset_sync (
    .clk         (uart_clk),
    .async_rst_n (uart_rst_n),
    .sync_rst_n  (uart_clk_rst_n)
  );

  reset_sync u_fifo_pclk_reset_sync (
    .clk         (pclk),
    .async_rst_n (fifo_async_rst_n),
    .sync_rst_n  (fifo_pclk_rst_n)
  );

  reset_sync u_fifo_uart_reset_sync (
    .clk         (uart_clk),
    .async_rst_n (fifo_async_rst_n),
    .sync_rst_n  (fifo_uart_rst_n)
  );

  // The UART side of the configuration mailbox is flushed with either
  // external reset. Its APB-side payload remains under presetn so a UART-only
  // reset can restore the programmed CTRL/BAUD snapshot after release.
  assign cfg_uart_rst_n = fifo_uart_rst_n;

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      ctrl_reg <= 32'h0;
      baud_reg <= 32'd16;
      cfg_ctrl_hold <= 3'b000;
      cfg_baud_hold <= 32'd16;
      cfg_req_tgl <= 1'b0;
      cfg_ack_pclk_q1 <= 1'b0;
      cfg_ack_pclk_q2 <= 1'b0;
      cfg_pending <= 1'b0;
      prdata   <= 32'h0;
      pslverr  <= 1'b0;
    end else begin
      cfg_ack_pclk_q1 <= cfg_ack_tgl;
      cfg_ack_pclk_q2 <= cfg_ack_pclk_q1;
      pslverr <= 1'b0;

      if (apb_access) begin
        unique case (paddr)
          ADDR_CTRL: begin
            if (pwrite) begin
              ctrl_reg <= pwdata & 32'h7;
            end else begin
              prdata <= ctrl_reg;
            end
          end

          ADDR_STATUS: begin
            if (pwrite) begin
              pslverr <= 1'b1;
            end else begin
              prdata <= {24'h0, rx_frame_err_pclk_q2, irq_o, rx_full_pclk_q2, rx_empty,
                         tx_full, tx_empty};
            end
          end

          ADDR_BAUD: begin
            if (pwrite) begin
              baud_reg <= (pwdata == 0) ? 32'd1 : pwdata;
            end else begin
              prdata <= baud_reg;
            end
          end

          ADDR_TXDATA: begin
            if (!pwrite) begin
              pslverr <= 1'b1;
              prdata  <= 32'h0;
            end else if (!enable_uart || tx_full) begin
              pslverr <= 1'b1;
            end
          end

          ADDR_RXDATA: begin
            if (pwrite || rx_empty) begin
              pslverr <= 1'b1;
              prdata  <= 32'h0;
            end else begin
              prdata <= {24'h0, rx_fifo_rdata};
            end
          end

          default: begin
            pslverr <= 1'b1;
            prdata  <= 32'h0;
          end
        endcase
      end

      // A busy mailbox keeps the in-flight payload untouched. If software
      // writes CTRL/BAUD again before the acknowledgement returns, only the
      // most recent APB-visible configuration is sent in the next transfer.
      if (cfg_write) begin
        if (!cfg_busy) begin
          cfg_ctrl_hold <= (paddr == ADDR_CTRL) ? pwdata[2:0] : ctrl_reg[2:0];
          cfg_baud_hold <= (paddr == ADDR_BAUD) ?
                           ((pwdata == 0) ? 32'd1 : pwdata) : baud_reg;
          cfg_req_tgl <= ~cfg_req_tgl;
          cfg_pending <= 1'b0;
        end else begin
          cfg_pending <= 1'b1;
        end
      end else if (!cfg_busy && cfg_pending) begin
        cfg_ctrl_hold <= ctrl_reg[2:0];
        cfg_baud_hold <= baud_reg;
        cfg_req_tgl <= ~cfg_req_tgl;
        cfg_pending <= 1'b0;
      end
    end
  end

  // These two status bits originate in uart_clk and are read through APB.
  // Synchronize them before exposing them in the pclk-domain STATUS register.
  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      rx_full_pclk_q1 <= 1'b0;
      rx_full_pclk_q2 <= 1'b0;
      rx_frame_err_pclk_q1 <= 1'b0;
      rx_frame_err_pclk_q2 <= 1'b0;
    end else begin
      rx_full_pclk_q1 <= rx_full_uart;
      rx_full_pclk_q2 <= rx_full_pclk_q1;
      rx_frame_err_pclk_q1 <= rx_frame_err_uart;
      rx_frame_err_pclk_q2 <= rx_frame_err_pclk_q1;
    end
  end

  always_ff @(posedge uart_clk or negedge cfg_uart_rst_n) begin
    if (!cfg_uart_rst_n) begin
      cfg_req_uart_q1 <= 1'b0;
      cfg_req_uart_q2 <= 1'b0;
      cfg_req_seen <= 1'b0;
      cfg_uart_initialized <= 1'b0;
      cfg_ack_tgl <= 1'b0;
      ctrl_uart_cfg <= 3'b000;
      baud_uart_cfg <= 32'd16;
    end else begin
      cfg_req_uart_q1 <= cfg_req_tgl;
      cfg_req_uart_q2 <= cfg_req_uart_q1;

      // Capture the reset-surviving APB configuration once after a UART-only
      // reset, then capture each later request after the two-flop synchronizer.
      if (!cfg_uart_initialized) begin
        ctrl_uart_cfg <= cfg_ctrl_hold;
        baud_uart_cfg <= cfg_baud_hold;
        cfg_req_seen <= cfg_req_uart_q2;
        cfg_ack_tgl <= cfg_req_uart_q2;
        cfg_uart_initialized <= 1'b1;
      end else if (cfg_req_uart_q2 != cfg_req_seen) begin
        ctrl_uart_cfg <= cfg_ctrl_hold;
        baud_uart_cfg <= cfg_baud_hold;
        cfg_req_seen <= cfg_req_uart_q2;
        cfg_ack_tgl <= cfg_req_uart_q2;
      end
    end
  end

  assign enable_uart_clk   = ctrl_uart_cfg[0];
  assign loopback_uart_clk = ctrl_uart_cfg[1];
  assign serial_rx         = loopback_uart_clk ? tx_o : rx_i;
  assign baud_divisor      = (baud_uart_cfg == 0) ? 32'd1 : baud_uart_cfg;

  always_ff @(posedge uart_clk or negedge uart_clk_rst_n) begin
    if (!uart_clk_rst_n) begin
      baud_cnt     <= 32'd0;
      baud_tick    <= 1'b0;
    end else begin
      baud_tick    <= 1'b0;

      if (!enable_uart_clk) begin
        baud_cnt <= 32'd0;
      end else if (baud_cnt >= (baud_divisor - 1)) begin
        baud_cnt  <= 32'd0;
        baud_tick <= 1'b1;
      end else begin
        baud_cnt <= baud_cnt + 32'd1;
      end
    end
  end

  async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_tx_fifo (
    .wr_clk   (pclk),
    .wr_rst_n (fifo_pclk_rst_n),
    .wr_en    (tx_push),
    .wr_data  (tx_fifo_wdata),
    .wr_full  (tx_full),
    .rd_clk   (uart_clk),
    .rd_rst_n (fifo_uart_rst_n),
    .rd_en    (tx_rd_en),
    .rd_data  (tx_fifo_rdata),
    .rd_empty (tx_empty)
  );

  async_fifo_sva #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_tx_fifo_sva (
    .wr_clk   (pclk),
    .wr_rst_n (fifo_pclk_rst_n),
    .wr_en    (tx_push),
    .wr_data  (tx_fifo_wdata),
    .wr_full  (tx_full),
    .rd_clk   (uart_clk),
    .rd_rst_n (fifo_uart_rst_n),
    .rd_en    (tx_rd_en),
    .rd_data  (tx_fifo_rdata),
    .rd_empty (tx_empty)
  );

  assign tx_rd_en = enable_uart_clk && baud_tick && tx_ready && !tx_empty;

  uart_tx u_uart_tx (
    .clk     (uart_clk),
    .rst_n   (uart_clk_rst_n),
    .enable  (enable_uart_clk),
    .bit_tick_i (baud_tick),
    .data_i  (tx_fifo_rdata),
    .valid_i (tx_rd_en),
    .ready_o (tx_ready),
    .tx_o    (tx_o)
  );

  uart_rx u_uart_rx (
    .clk         (uart_clk),
    .rst_n       (uart_clk_rst_n),
    .enable      (enable_uart_clk),
    .bit_tick_i  (baud_tick),
    .rx_i        (serial_rx),
    .data_o      (rx_data),
    .valid_o     (rx_valid),
    .ready_i     (!rx_full_uart),
    .frame_err_o (rx_frame_err_uart)
  );

  assign rx_wr_en = rx_valid && !rx_full_uart;

  async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_rx_fifo (
    .wr_clk   (uart_clk),
    .wr_rst_n (fifo_uart_rst_n),
    .wr_en    (rx_wr_en),
    .wr_data  (rx_data),
    .wr_full  (rx_full_uart),
    .rd_clk   (pclk),
    .rd_rst_n (fifo_pclk_rst_n),
    .rd_en    (rx_pop),
    .rd_data  (rx_fifo_rdata),
    .rd_empty (rx_empty)
  );

  async_fifo_sva #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_rx_fifo_sva (
    .wr_clk   (uart_clk),
    .wr_rst_n (fifo_uart_rst_n),
    .wr_en    (rx_wr_en),
    .wr_data  (rx_data),
    .wr_full  (rx_full_uart),
    .rd_clk   (pclk),
    .rd_rst_n (fifo_pclk_rst_n),
    .rd_en    (rx_pop),
    .rd_data  (rx_fifo_rdata),
    .rd_empty (rx_empty)
  );

endmodule
