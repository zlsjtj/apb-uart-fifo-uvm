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
  logic        rx_full;
  logic        rx_empty;
  logic [7:0]  tx_fifo_rdata;
  logic [7:0]  rx_fifo_rdata;

  logic        enable_uart;
  logic        loopback_en;
  logic        irq_en;

  logic [2:0]  ctrl_uart_q1, ctrl_uart_q2;
  logic        enable_uart_clk;
  logic        loopback_uart_clk;

  logic        tx_ready;
  logic        tx_rd_en;
  logic        serial_rx;
  logic [7:0]  rx_data;
  logic        rx_valid;
  logic        rx_frame_err;
  logic        rx_wr_en;

  assign apb_access  = psel && penable;
  assign pready      = 1'b1;
  assign enable_uart = ctrl_reg[0];
  assign loopback_en = ctrl_reg[1];
  assign irq_en      = ctrl_reg[2];
  assign irq_o       = irq_en && !rx_empty;

  assign tx_push = apb_access && pwrite && (paddr == ADDR_TXDATA) &&
                   enable_uart && !tx_full;
  assign rx_pop  = apb_access && !pwrite && (paddr == ADDR_RXDATA) &&
                   !rx_empty;

  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      ctrl_reg <= 32'h0;
      baud_reg <= 32'd16;
      prdata   <= 32'h0;
      pslverr  <= 1'b0;
    end else begin
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
              prdata <= {24'h0, rx_frame_err, irq_o, rx_full, rx_empty,
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
    end
  end

  always_ff @(posedge uart_clk or negedge uart_rst_n) begin
    if (!uart_rst_n) begin
      ctrl_uart_q1 <= '0;
      ctrl_uart_q2 <= '0;
    end else begin
      ctrl_uart_q1 <= {irq_en, loopback_en, enable_uart};
      ctrl_uart_q2 <= ctrl_uart_q1;
    end
  end

  assign enable_uart_clk   = ctrl_uart_q2[0];
  assign loopback_uart_clk = ctrl_uart_q2[1];
  assign serial_rx         = loopback_uart_clk ? tx_o : rx_i;

  async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_tx_fifo (
    .wr_clk   (pclk),
    .wr_rst_n (presetn),
    .wr_en    (tx_push),
    .wr_data  (pwdata[7:0]),
    .wr_full  (tx_full),
    .rd_clk   (uart_clk),
    .rd_rst_n (uart_rst_n),
    .rd_en    (tx_rd_en),
    .rd_data  (tx_fifo_rdata),
    .rd_empty (tx_empty)
  );

  async_fifo_sva #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_tx_fifo_sva (
    .wr_clk   (pclk),
    .wr_rst_n (presetn),
    .wr_en    (tx_push),
    .wr_data  (pwdata[7:0]),
    .wr_full  (tx_full),
    .rd_clk   (uart_clk),
    .rd_rst_n (uart_rst_n),
    .rd_en    (tx_rd_en),
    .rd_data  (tx_fifo_rdata),
    .rd_empty (tx_empty)
  );

  assign tx_rd_en = enable_uart_clk && tx_ready && !tx_empty;

  uart_tx u_uart_tx (
    .clk     (uart_clk),
    .rst_n   (uart_rst_n),
    .enable  (enable_uart_clk),
    .data_i  (tx_fifo_rdata),
    .valid_i (tx_rd_en),
    .ready_o (tx_ready),
    .tx_o    (tx_o)
  );

  uart_rx u_uart_rx (
    .clk         (uart_clk),
    .rst_n       (uart_rst_n),
    .enable      (enable_uart_clk),
    .rx_i        (serial_rx),
    .data_o      (rx_data),
    .valid_o     (rx_valid),
    .ready_i     (!rx_full),
    .frame_err_o (rx_frame_err)
  );

  assign rx_wr_en = rx_valid && !rx_full;

  async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_rx_fifo (
    .wr_clk   (uart_clk),
    .wr_rst_n (uart_rst_n),
    .wr_en    (rx_wr_en),
    .wr_data  (rx_data),
    .wr_full  (rx_full),
    .rd_clk   (pclk),
    .rd_rst_n (presetn),
    .rd_en    (rx_pop),
    .rd_data  (rx_fifo_rdata),
    .rd_empty (rx_empty)
  );

  async_fifo_sva #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) u_rx_fifo_sva (
    .wr_clk   (uart_clk),
    .wr_rst_n (uart_rst_n),
    .wr_en    (rx_wr_en),
    .wr_data  (rx_data),
    .wr_full  (rx_full),
    .rd_clk   (pclk),
    .rd_rst_n (presetn),
    .rd_en    (rx_pop),
    .rd_data  (rx_fifo_rdata),
    .rd_empty (rx_empty)
  );

endmodule
