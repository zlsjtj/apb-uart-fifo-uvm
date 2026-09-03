class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_sequencer seqr;
  uart_driver    drv;
  uart_monitor   mon;
  uart_rx_monitor rx_mon;
  uart_config_monitor cfg_mon;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = uart_monitor::type_id::create("mon", this);
    rx_mon = uart_rx_monitor::type_id::create("rx_mon", this);
    cfg_mon = uart_config_monitor::type_id::create("cfg_mon", this);

    if (is_active == UVM_ACTIVE) begin
      seqr = uart_sequencer::type_id::create("seqr", this);
      drv  = uart_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass
