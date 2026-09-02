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

class uart_reset_cdc_test extends uart_base_test;
  `uvm_component_utils(uart_reset_cdc_test)

  virtual reset_if reset_vif;

  function new(string name = "uart_reset_cdc_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_reset_midflight_seq        midflight_seq;
    uart_reset_defaults_seq         defaults_seq;
    uart_reset_preserved_config_seq preserved_seq;
    uart_reset_recovery_seq         recovery_seq;

    phase.raise_objection(this);
    midflight_seq = uart_reset_midflight_seq::type_id::create("midflight_seq");
    defaults_seq  = uart_reset_defaults_seq::type_id::create("defaults_seq");
    preserved_seq = uart_reset_preserved_config_seq::type_id::create("preserved_seq");
    recovery_seq  = uart_reset_recovery_seq::type_id::create("recovery_seq");

    // Reset both domains while a TX byte is pending, then prove clean recovery.
    midflight_seq.start(env.apb.seqr);
    reset_vif.pulse_both(3, 3);
    defaults_seq.start(env.apb.seqr);
    recovery_seq.start(env.apb.seqr);

    // APB-only reset clears APB configuration and both FIFO pointer domains.
    reset_vif.pulse_apb_reset(3);
    defaults_seq.start(env.apb.seqr);
    recovery_seq.start(env.apb.seqr);

    // UART-only reset keeps APB configuration but flushes both FIFOs.
    reset_vif.pulse_uart_reset(3);
    preserved_seq.start(env.apb.seqr);
    recovery_seq.start(env.apb.seqr);

    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_baud_timing_test extends uart_base_test;
  `uvm_component_utils(uart_baud_timing_test)

  virtual uart_if timing_vif;
  bit [31:0] cov_baud_programmed;
  bit        cov_timing_pass;
  realtime   uart_period;

  covergroup baud_timing_cg;
    option.per_instance = 1;

    cp_baud: coverpoint cov_baud_programmed {
      bins zero  = {32'd0};
      bins one   = {32'd1};
      bins four  = {32'd4};
      bins eight = {32'd8};
    }

    cp_result: coverpoint cov_timing_pass {
      bins pass = {1'b1};
      illegal_bins fail = {1'b0};
    }

    cross cp_baud, cp_result;
  endgroup

  function new(string name = "uart_baud_timing_test", uvm_component parent = null);
    super.new(name, parent);
    baud_timing_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "timing_vif", timing_vif)) begin
      `uvm_fatal("NOTIMINGVIF", "UART timing interface is not set")
    end
  endfunction

  task automatic measure_frame(input bit [31:0] programmed_baud);
    realtime last_edge;
    realtime this_edge;
    realtime measured;
    realtime expected;
    realtime difference;
    int unsigned effective_baud;

    effective_baud = (programmed_baud == 0) ? 1 : programmed_baud;
    expected = uart_period * effective_baud;
    cov_timing_pass = 1'b1;

    // 0x55 changes level at every frame bit boundary. Starting at the falling
    // start-bit edge gives nine independent bit-width measurements.
    @(negedge timing_vif.tx_o);
    last_edge = $realtime;
    for (int i = 0; i < 9; i++) begin
      @(timing_vif.tx_o);
      this_edge = $realtime;
      measured = this_edge - last_edge;
      difference = (measured > expected) ? (measured - expected)
                                         : (expected - measured);
      if (difference > 1ps) begin
        cov_timing_pass = 1'b0;
        `uvm_error("BAUD_TIMING",
                   $sformatf("BAUD=%0d bit=%0d measured=%0t expected=%0t",
                             programmed_baud, i, measured, expected))
      end
      last_edge = this_edge;
    end

    cov_baud_programmed = programmed_baud;
    baud_timing_cg.sample();
    `uvm_info("BAUD_TIMING",
              $sformatf("BAUD=%0d effective=%0d measured bit width=%0t",
                        programmed_baud, effective_baud, expected),
              UVM_LOW)
  endtask

  task automatic run_baud_case(input bit [31:0] programmed_baud);
    uart_baud_tx_seq seq;
    seq = uart_baud_tx_seq::type_id::create($sformatf("baud_%0d_seq", programmed_baud));
    seq.baud_value = programmed_baud;
    fork
      seq.start(env.apb.seqr);
      measure_frame(programmed_baud);
    join
  endtask

  task run_phase(uvm_phase phase);
    realtime first_edge;

    phase.raise_objection(this);
    @(posedge timing_vif.uart_clk);
    first_edge = $realtime;
    @(posedge timing_vif.uart_clk);
    uart_period = $realtime - first_edge;

    run_baud_case(32'd0);
    run_baud_case(32'd1);
    run_baud_case(32'd4);
    run_baud_case(32'd8);

    #1us;
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
