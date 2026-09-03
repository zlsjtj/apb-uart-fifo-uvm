module apb_uart_regs (
  input  logic        pclk,
  input  logic        pclk_rst_n,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [7:0]  paddr,
  input  logic [31:0] pwdata,
  input  logic        tx_full,
  input  logic        tx_empty,
  input  logic        rx_full,
  input  logic        rx_empty,
  input  logic [7:0]  rx_fifo_rdata,
  input  logic        rx_frame_err,
  input  logic        irq,
  input  logic        cfg_busy,
  output logic [31:0] prdata,
  output logic        pslverr,
  output logic [31:0] ctrl_reg,
  output logic [31:0] baud_reg,
  output logic        tx_push,
  output logic        rx_pop,
  output logic        cfg_write,
  output logic [2:0]  cfg_ctrl_value,
  output logic [31:0] cfg_baud_value
);
  import apb_uart_reg_pkg::*;

  logic apb_access;
  logic enable_uart;

  assign apb_access  = psel && penable;
  assign enable_uart = ctrl_reg[UART_CTRL_ENABLE_BIT];
  assign cfg_write   = apb_access && pwrite &&
                       ((paddr == UART_ADDR_CTRL) || (paddr == UART_ADDR_BAUD));
  assign tx_push     = apb_access && pwrite && (paddr == UART_ADDR_TXDATA) &&
                       enable_uart && !tx_full;
  assign rx_pop      = apb_access && !pwrite && (paddr == UART_ADDR_RXDATA) &&
                       !rx_empty;

  always_comb begin
    cfg_ctrl_value = ctrl_reg[2:0];
    cfg_baud_value = baud_reg;
    if (cfg_write && (paddr == UART_ADDR_CTRL)) begin
      cfg_ctrl_value = pwdata[2:0] & UART_CTRL_MASK[2:0];
    end
    if (cfg_write && (paddr == UART_ADDR_BAUD)) begin
      cfg_baud_value = (pwdata == 0) ? UART_BAUD_MIN : pwdata;
    end
  end

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      ctrl_reg <= UART_CTRL_RESET;
      baud_reg <= UART_BAUD_RESET;
      prdata   <= 32'h0;
      pslverr  <= 1'b0;
    end else begin
      pslverr <= 1'b0;
      if (apb_access) begin
        unique case (paddr)
          UART_ADDR_CTRL: begin
            if (pwrite) ctrl_reg <= pwdata & UART_CTRL_MASK;
            else        prdata <= ctrl_reg;
          end
          UART_ADDR_STATUS: begin
            if (pwrite) pslverr <= 1'b1;
            else prdata <= {24'h0, rx_frame_err, irq, rx_full, rx_empty,
                            tx_full, tx_empty};
          end
          UART_ADDR_BAUD: begin
            if (pwrite) baud_reg <= (pwdata == 0) ? UART_BAUD_MIN : pwdata;
            else        prdata <= baud_reg;
          end
          UART_ADDR_TXDATA: begin
            if (!pwrite) begin
              pslverr <= 1'b1;
              prdata  <= 32'h0;
            end else if (!enable_uart || tx_full) begin
              pslverr <= 1'b1;
            end
          end
          UART_ADDR_RXDATA: begin
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
endmodule
