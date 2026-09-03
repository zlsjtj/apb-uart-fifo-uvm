class uart_serial_cfg extends uvm_object;
  `uvm_object_utils(uart_serial_cfg)

  bit [2:0]  ctrl;
  bit [31:0] baud;
  int unsigned apb_updates;

  function new(string name = "uart_serial_cfg");
    super.new(name);
    reset_to_defaults();
  endfunction

  function void reset_to_defaults();
    ctrl = UART_CTRL_RESET[2:0];
    baud = UART_BAUD_RESET;
  endfunction

  function int unsigned divisor();
    return (baud == 0) ? UART_BAUD_MIN : baud;
  endfunction
endclass
