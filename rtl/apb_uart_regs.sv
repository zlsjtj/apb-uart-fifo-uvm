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
  input  logic        tx_busy,
  input  logic        fifo_ready,
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
                       pclk_rst_n && fifo_ready && enable_uart && !tx_full;
  assign rx_pop      = apb_access && !pwrite && (paddr == UART_ADDR_RXDATA) &&
                       pclk_rst_n && fifo_ready && !rx_empty;

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

  // Zero-wait APB responses must be valid BEFORE the completing rising edge.
  // Only storage updates and FIFO side effects happen at that edge.
  always_comb begin
    prdata = '0;
    pslverr = 1'b0;
    if (pclk_rst_n && apb_access) begin
      unique case (paddr)
        UART_ADDR_CTRL: prdata = ctrl_reg;
        UART_ADDR_STATUS: begin
          prdata = {24'h0, tx_busy, cfg_busy, rx_frame_err, irq, rx_full, rx_empty,
                    tx_full, tx_empty};
          pslverr = pwrite;
        end
        UART_ADDR_BAUD: prdata = baud_reg;
        UART_ADDR_TXDATA: pslverr = !pwrite || !fifo_ready || !enable_uart || tx_full;
        UART_ADDR_RXDATA: begin
          pslverr = pwrite || !fifo_ready || rx_empty;
          if (!pslverr) prdata = {24'h0, rx_fifo_rdata};
        end
        default: pslverr = 1'b1;
      endcase
    end
  end

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      ctrl_reg <= UART_CTRL_RESET;
      baud_reg <= UART_BAUD_RESET;
    end else begin
      if (apb_access && pwrite) begin
        if (paddr == UART_ADDR_CTRL) ctrl_reg <= pwdata & UART_CTRL_MASK;
        if (paddr == UART_ADDR_BAUD)
          baud_reg <= (pwdata == 0) ? UART_BAUD_MIN : pwdata;
      end
    end
  end
endmodule
