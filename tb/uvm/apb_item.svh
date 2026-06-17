class apb_item extends uvm_sequence_item;
  typedef enum bit {
    APB_READ  = 1'b0,
    APB_WRITE = 1'b1
  } apb_kind_e;

  rand apb_kind_e   kind;
  rand bit [7:0]    addr;
  rand bit [31:0]   data;
  rand int unsigned idle_cycles;

  bit [31:0] rdata;
  bit        slverr;

  constraint c_idle {
    idle_cycles inside {[0:8]};
  }

  `uvm_object_utils_begin(apb_item)
    `uvm_field_enum(apb_kind_e, kind, UVM_ALL_ON)
    `uvm_field_int(addr,        UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,        UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_field_int(rdata,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(slverr,      UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%02h wdata=0x%08h rdata=0x%08h slverr=%0b idle=%0d",
                     kind.name(), addr, data, rdata, slverr, idle_cycles);
  endfunction
endclass
