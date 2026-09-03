class uart_env_cfg extends uvm_object;
  int unsigned fifo_addr_width = 4;
  int unsigned data_bits       = 8;
  int unsigned stop_bits       = 1;
  int unsigned pclk_half_ns    = 5;
  int unsigned uart_half_ns    = 20;
  int unsigned pclk_phase_ns   = 0;
  int unsigned uart_phase_ns   = 0;

  `uvm_object_utils_begin(uart_env_cfg)
    `uvm_field_int(fifo_addr_width, UVM_DEFAULT)
    `uvm_field_int(data_bits,       UVM_DEFAULT)
    `uvm_field_int(stop_bits,       UVM_DEFAULT)
    `uvm_field_int(pclk_half_ns,    UVM_DEFAULT)
    `uvm_field_int(uart_half_ns,    UVM_DEFAULT)
    `uvm_field_int(pclk_phase_ns,   UVM_DEFAULT)
    `uvm_field_int(uart_phase_ns,   UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "uart_env_cfg");
    super.new(name);
  endfunction

  function int unsigned fifo_depth();
    return 1 << fifo_addr_width;
  endfunction

  function void validate();
    if ((fifo_addr_width == 0) || (fifo_addr_width > 16)) begin
      `uvm_fatal("BAD_CFG", $sformatf("fifo_addr_width=%0d is outside 1..16",
                                      fifo_addr_width))
    end
    if ((data_bits != 8) || (stop_bits != 1)) begin
      `uvm_fatal("BAD_CFG", "this DUT supports exactly 8 data bits and 1 stop bit")
    end
    if ((pclk_half_ns == 0) || (uart_half_ns == 0)) begin
      `uvm_fatal("BAD_CFG", "clock half-periods must be non-zero")
    end
  endfunction
endclass
