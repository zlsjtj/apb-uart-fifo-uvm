class uart_item extends uvm_sequence_item;
  rand bit [7:0]    data;
  rand int unsigned gap_cycles;
  bit               frame_err;

  constraint c_gap {
    gap_cycles inside {[1:12]};
  }

  `uvm_object_utils_begin(uart_item)
    `uvm_field_int(data,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(gap_cycles, UVM_ALL_ON)
    `uvm_field_int(frame_err,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("uart data=0x%02h gap=%0d frame_err=%0b",
                     data, gap_cycles, frame_err);
  endfunction
endclass
