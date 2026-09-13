class uart_tx_completion_test extends uart_base_test;
  `uvm_component_utils(uart_tx_completion_test)
  function new(string name, uvm_component parent=null); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    uart_tx_completion_seq seq;
    phase.raise_objection(this);
    seq=uart_tx_completion_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_fifo_wrap_test extends uart_base_test;
  `uvm_component_utils(uart_fifo_wrap_test)
  function new(string name, uvm_component parent=null); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    uart_fifo_wrap_seq seq;
    phase.raise_objection(this);
    seq=uart_fifo_wrap_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_no_probe_test extends uart_base_test;
  `uvm_component_utils(uart_no_probe_test)
  function new(string name, uvm_component parent=null); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    uart_tx_completion_seq tx;
    uart_external_rx_vseq rx;
    phase.raise_objection(this);
    if (env.cfg.enable_whitebox)
      `uvm_fatal("NO_PROBE", "This test must elaborate with ENABLE_WHITEBOX=0")
`ifndef UART_NO_WHITEBOX
    if (env.cfg_mon != null || env.cfg_checker != null)
      `uvm_fatal("NO_PROBE", "White-box components unexpectedly instantiated")
`endif
    tx=uart_tx_completion_seq::type_id::create("tx");
    tx.start(env.apb.seqr);
    rx=uart_external_rx_vseq::type_id::create("rx");
    rx.start(env.vseqr);
    #1us;
    `uvm_info("NO_PROBE", "Public-pin TX and external RX passed without a probe interface", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
