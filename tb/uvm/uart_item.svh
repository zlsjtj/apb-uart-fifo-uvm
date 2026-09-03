class uart_item extends uvm_sequence_item;
  rand bit [7:0]    data;
  rand int unsigned gap_cycles;
  int unsigned      bit_cycles = 1;
  int unsigned      edge_offset_ps = 1000;
  bit               frame_err;

  constraint c_gap {
    gap_cycles inside {[1:12]};
  }

  `uvm_object_utils_begin(uart_item)
    `uvm_field_int(data,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(gap_cycles, UVM_ALL_ON)
    `uvm_field_int(bit_cycles, UVM_ALL_ON)
    `uvm_field_int(edge_offset_ps, UVM_ALL_ON)
    `uvm_field_int(frame_err,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("uart data=0x%02h gap=%0d bit_cycles=%0d edge_offset_ps=%0d frame_err=%0b",
                     data, gap_cycles, bit_cycles, edge_offset_ps, frame_err);
  endfunction
endclass

class uart_cfg_item extends uvm_sequence_item;
  bit [2:0]  ctrl;
  bit [31:0] baud;
  time       effective_time;

  `uvm_object_utils_begin(uart_cfg_item)
    `uvm_field_int(ctrl, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(baud, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_cfg_item");
    super.new(name);
  endfunction
endclass
