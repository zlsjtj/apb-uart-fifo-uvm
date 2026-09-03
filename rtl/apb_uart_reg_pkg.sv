package apb_uart_reg_pkg;

  // The current teaching DUT implements a fixed 8N1 frame. Keep these as
  // capability constants instead of mutable testbench configuration fields.
  localparam int unsigned UART_DATA_BITS = 8;
  localparam int unsigned UART_STOP_BITS = 1;

  localparam logic [7:0] UART_ADDR_CTRL   = 8'h00;
  localparam logic [7:0] UART_ADDR_STATUS = 8'h04;
  localparam logic [7:0] UART_ADDR_BAUD   = 8'h08;
  localparam logic [7:0] UART_ADDR_TXDATA = 8'h0c;
  localparam logic [7:0] UART_ADDR_RXDATA = 8'h10;

  localparam logic [31:0] UART_CTRL_RESET = 32'h0000_0000;
  localparam logic [31:0] UART_CTRL_MASK  = 32'h0000_0007;
  localparam logic [31:0] UART_STATUS_RESET = 32'h0000_0005;
  localparam logic [31:0] UART_BAUD_MIN   = 32'd1;
  localparam logic [31:0] UART_BAUD_RESET = 32'd16;

  localparam int unsigned UART_CTRL_ENABLE_BIT   = 0;
  localparam int unsigned UART_CTRL_LOOPBACK_BIT = 1;
  localparam int unsigned UART_CTRL_IRQ_EN_BIT   = 2;

  localparam int unsigned UART_STATUS_TX_EMPTY_BIT  = 0;
  localparam int unsigned UART_STATUS_TX_FULL_BIT   = 1;
  localparam int unsigned UART_STATUS_RX_EMPTY_BIT  = 2;
  localparam int unsigned UART_STATUS_RX_FULL_BIT   = 3;
  localparam int unsigned UART_STATUS_IRQ_BIT       = 4;
  localparam int unsigned UART_STATUS_FRAME_ERR_BIT = 5;

  function automatic logic uart_addr_is_legal(input logic [7:0] addr);
    return (addr == UART_ADDR_CTRL)   ||
           (addr == UART_ADDR_STATUS) ||
           (addr == UART_ADDR_BAUD)   ||
           (addr == UART_ADDR_TXDATA) ||
           (addr == UART_ADDR_RXDATA);
  endfunction

endpackage
