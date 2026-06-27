class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;

  function new(string name = "uart_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "env.apb",  "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "env.uart", "is_active", UVM_ACTIVE);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction
endclass

class uart_reg_test extends uart_base_test;
  `uvm_component_utils(uart_reg_test)

  function new(string name = "uart_reg_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_reg_seq seq;
    phase.raise_objection(this);
    seq = uart_reg_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

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

class uart_random_test extends uart_base_test;
  `uvm_component_utils(uart_random_test)

  function new(string name = "uart_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_random_apb_seq seq;
    phase.raise_objection(this);
    seq = uart_random_apb_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #2us;
    phase.drop_objection(this);
  endtask
endclass

class uart_fifo_full_test extends uart_base_test;
  `uvm_component_utils(uart_fifo_full_test)

  function new(string name = "uart_fifo_full_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_fifo_full_seq seq;
    phase.raise_objection(this);
    seq = uart_fifo_full_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #2us;
    phase.drop_objection(this);
  endtask
endclass

class uart_bad_access_test extends uart_base_test;
  `uvm_component_utils(uart_bad_access_test)

  function new(string name = "uart_bad_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_bad_access_seq seq;
    phase.raise_objection(this);
    seq = uart_bad_access_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_external_rx_test extends uart_base_test;
  `uvm_component_utils(uart_external_rx_test)

  function new(string name = "uart_external_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_rx_read_seq    apb_seq;
    uart_external_rx_seq rx_seq;

    phase.raise_objection(this);
    apb_seq = uart_rx_read_seq::type_id::create("apb_seq");
    rx_seq  = uart_external_rx_seq::type_id::create("rx_seq");

    fork
      apb_seq.start(env.apb.seqr);
      rx_seq.start(env.uart.seqr);
    join

    #2us;
    phase.drop_objection(this);
  endtask
endclass

class uart_recover_test extends uart_base_test;
  `uvm_component_utils(uart_recover_test)

  function new(string name = "uart_recover_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_disable_recover_seq seq;
    phase.raise_objection(this);
    seq = uart_disable_recover_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #2us;
    phase.drop_objection(this);
  endtask
endclass
