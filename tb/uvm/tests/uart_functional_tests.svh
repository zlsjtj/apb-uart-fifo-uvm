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
    uart_frame_error_setup_seq    setup_seq;
    uart_bad_frame_seq            bad_seq;
    uart_frame_error_check_seq    error_check_seq;
    uart_good_recovery_seq        good_seq;
    uart_frame_recovery_check_seq recovery_check_seq;

    phase.raise_objection(this);
    setup_seq          = uart_frame_error_setup_seq::type_id::create("setup_seq");
    bad_seq            = uart_bad_frame_seq::type_id::create("bad_seq");
    error_check_seq    = uart_frame_error_check_seq::type_id::create("error_check_seq");
    good_seq           = uart_good_recovery_seq::type_id::create("good_seq");
    recovery_check_seq = uart_frame_recovery_check_seq::type_id::create("recovery_check_seq");

    setup_seq.start(env.apb.seqr);
    bad_seq.start(env.uart.seqr);
    error_check_seq.start(env.apb.seqr);
    good_seq.start(env.uart.seqr);
    recovery_check_seq.start(env.apb.seqr);

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
    uart_rx_fifo_setup_seq          setup_seq;
    uart_rx_fifo_burst_seq          burst_seq;
    uart_rx_fifo_drain_seq          drain_seq;
    uart_rx_fifo_recovery_uart_seq  recovery_uart_seq;
    uart_rx_fifo_recovery_check_seq recovery_check_seq;

    phase.raise_objection(this);
    setup_seq          = uart_rx_fifo_setup_seq::type_id::create("setup_seq");
    burst_seq          = uart_rx_fifo_burst_seq::type_id::create("burst_seq");
    drain_seq          = uart_rx_fifo_drain_seq::type_id::create("drain_seq");
    recovery_uart_seq  = uart_rx_fifo_recovery_uart_seq::type_id::create("recovery_uart_seq");
    recovery_check_seq = uart_rx_fifo_recovery_check_seq::type_id::create("recovery_check_seq");

    setup_seq.start(env.apb.seqr);
    burst_seq.start(env.uart.seqr);
    drain_seq.start(env.apb.seqr);
    recovery_uart_seq.start(env.uart.seqr);
    recovery_check_seq.start(env.apb.seqr);

    #1us;
    phase.drop_objection(this);
  endtask
endclass

