class uart_ctrl_reg extends uvm_reg;
  `uvm_object_utils(uart_ctrl_reg)

  rand uvm_reg_field value;

  function new(string name = "uart_ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 3, 0, "RW", 0, UART_CTRL_RESET, 1, 1, 0);
  endfunction
endclass

class uart_status_reg extends uvm_reg;
  `uvm_object_utils(uart_status_reg)

  uvm_reg_field value;

  function new(string name = "uart_status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 8, 0, "RO", 1, UART_STATUS_RESET, 1, 0, 0);
  endfunction
endclass

class uart_baud_reg extends uvm_reg;
  `uvm_object_utils(uart_baud_reg)

  rand uvm_reg_field value;

  function new(string name = "uart_baud_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 0, UART_BAUD_RESET, 1, 1, 0);
  endfunction
endclass

class uart_txdata_reg extends uvm_reg;
  `uvm_object_utils(uart_txdata_reg)

  rand uvm_reg_field value;

  function new(string name = "uart_txdata_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 8, 0, "WO", 1, 0, 0, 1, 0);
  endfunction
endclass

class uart_rxdata_reg extends uvm_reg;
  `uvm_object_utils(uart_rxdata_reg)

  uvm_reg_field value;

  function new(string name = "uart_rxdata_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 8, 0, "RO", 1, 0, 0, 0, 0);
  endfunction
endclass

class uart_reg_block extends uvm_reg_block;
  `uvm_object_utils(uart_reg_block)

  rand uart_ctrl_reg   ctrl;
       uart_status_reg status;
  rand uart_baud_reg   baud;
  rand uart_txdata_reg txdata;
       uart_rxdata_reg rxdata;

  function new(string name = "uart_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    ctrl = uart_ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this);
    ctrl.build();

    status = uart_status_reg::type_id::create("status");
    status.configure(this);
    status.build();

    baud = uart_baud_reg::type_id::create("baud");
    baud.configure(this);
    baud.build();

    txdata = uart_txdata_reg::type_id::create("txdata");
    txdata.configure(this);
    txdata.build();

    rxdata = uart_rxdata_reg::type_id::create("rxdata");
    rxdata.configure(this);
    rxdata.build();

    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 1);
    default_map.add_reg(ctrl,   UART_ADDR_CTRL,   "RW");
    default_map.add_reg(status, UART_ADDR_STATUS, "RO");
    default_map.add_reg(baud,   UART_ADDR_BAUD,   "RW");
    default_map.add_reg(txdata, UART_ADDR_TXDATA, "WO");
    default_map.add_reg(rxdata, UART_ADDR_RXDATA, "RO");
  endfunction
endclass

class uart_apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(uart_apb_reg_adapter)

  function new(string name = "uart_apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_item tr;
    tr = apb_item::type_id::create("ral_apb_item");
    tr.kind = (rw.kind == UVM_READ) ? apb_item::APB_READ : apb_item::APB_WRITE;
    tr.addr = rw.addr[7:0];
    tr.data = rw.data[31:0];
    tr.idle_cycles = 0;
    return tr;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    apb_item tr;
    if (!$cast(tr, bus_item)) begin
      `uvm_fatal("RAL_ADAPTER", "bus_item is not an apb_item")
    end

    rw.kind = (tr.kind == apb_item::APB_READ) ? UVM_READ : UVM_WRITE;
    rw.addr = tr.addr;
    rw.data = (rw.kind == UVM_READ) ? tr.rdata : tr.data;
    rw.status = tr.slverr ? UVM_NOT_OK : UVM_IS_OK;

    // Prediction must describe the state stored by the DUT, not just the raw
    // APB write data.
    if ((rw.status == UVM_IS_OK) && (rw.kind == UVM_WRITE)) begin
      if (tr.addr == UART_ADDR_CTRL) begin
        rw.data &= UART_CTRL_MASK;
      end else if ((tr.addr == UART_ADDR_BAUD) && (tr.data == 0)) begin
        rw.data = UART_BAUD_MIN;
      end
    end
  endfunction
endclass
