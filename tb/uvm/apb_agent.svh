class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_sequencer seqr;
  apb_driver    drv;
  apb_monitor   mon;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);

    if (is_active == UVM_ACTIVE) begin
      seqr = apb_sequencer::type_id::create("seqr", this);
      drv  = apb_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass
