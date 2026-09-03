class uart_loopback_test extends uart_base_test;
  `uvm_component_utils(uart_loopback_test)

  function new(string name = "uart_loopback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_loopback_seq seq;
    phase.raise_objection(this);
    seq = uart_loopback_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #2us;
    phase.drop_objection(this);
  endtask
endclass

class uart_baud_loopback_test extends uart_base_test;
  `uvm_component_utils(uart_baud_loopback_test)

  function new(string name = "uart_baud_loopback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_baud_loopback_seq seq;
    phase.raise_objection(this);
    seq = uart_baud_loopback_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #2us;
    phase.drop_objection(this);
  endtask
endclass

class uart_irq_test extends uart_base_test;
  `uvm_component_utils(uart_irq_test)

  function new(string name = "uart_irq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_irq_seq seq;
    phase.raise_objection(this);
    seq = uart_irq_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_frame_error_test extends uart_base_test;
  `uvm_component_utils(uart_frame_error_test)

  function new(string name = "uart_frame_error_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_frame_error_vseq vseq;

    phase.raise_objection(this);
    vseq = uart_frame_error_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_rx_fifo_full_test extends uart_base_test;
  `uvm_component_utils(uart_rx_fifo_full_test)

  function new(string name = "uart_rx_fifo_full_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_rx_fifo_full_vseq vseq;

    phase.raise_objection(this);
    vseq = uart_rx_fifo_full_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #1us;
    phase.drop_objection(this);
  endtask
endclass
