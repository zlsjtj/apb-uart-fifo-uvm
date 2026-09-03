class uart_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(uart_virtual_sequencer)

  apb_sequencer  apb_seqr;
  uart_sequencer uart_seqr;
  virtual reset_if reset_vif;

  function new(string name = "uart_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction
endclass
