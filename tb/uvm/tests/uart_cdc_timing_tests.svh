class uart_reset_cdc_test extends uart_base_test;
  `uvm_component_utils(uart_reset_cdc_test)

  function new(string name = "uart_reset_cdc_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_reset_cdc_vseq vseq;

    phase.raise_objection(this);
    vseq = uart_reset_cdc_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

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
