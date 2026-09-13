class uart_base_vseq extends uvm_sequence;
  `uvm_object_utils(uart_base_vseq)
  `uvm_declare_p_sequencer(uart_virtual_sequencer)

  function new(string name = "uart_base_vseq");
    super.new(name);
  endfunction
endclass

class uart_external_rx_vseq extends uart_base_vseq;
  `uvm_object_utils(uart_external_rx_vseq)

  bit [31:0] baud_value = 32'd1;
  int unsigned bit_cycles = 1;
  int unsigned edge_offset_ps = 1000;

  function new(string name = "uart_external_rx_vseq");
    super.new(name);
  endfunction

  task body();
    uart_rx_read_seq     apb_seq;
    uart_external_rx_seq rx_seq;
    uart_rx_config_seq config_seq;

    apb_seq = uart_rx_read_seq::type_id::create("apb_seq");
    rx_seq  = uart_external_rx_seq::type_id::create("rx_seq");
    apb_seq.baud_value = baud_value;
    apb_seq.configure_first = 1'b0;
    config_seq = uart_rx_config_seq::type_id::create("config_seq");
    config_seq.baud_value = baud_value;
    config_seq.start(p_sequencer.apb_seqr);
    rx_seq.bit_cycles = bit_cycles;
    rx_seq.edge_offset_ps = edge_offset_ps;
    if (bit_cycles > 1) begin
      apb_seq.first_read_idle = 120 + (75 * bit_cycles);
      apb_seq.next_read_idle = 20 + (50 * bit_cycles);
    end
    fork
      apb_seq.start(p_sequencer.apb_seqr);
      rx_seq.start(p_sequencer.uart_seqr);
    join
  endtask
endclass

class uart_frame_error_vseq extends uart_base_vseq;
  `uvm_object_utils(uart_frame_error_vseq)

  function new(string name = "uart_frame_error_vseq");
    super.new(name);
  endfunction

  task body();
    uart_frame_error_setup_seq setup_seq;
    uart_bad_frame_seq bad_seq;
    uart_frame_error_check_seq error_check_seq;
    uart_good_recovery_seq good_seq;
    uart_frame_recovery_check_seq recovery_check_seq;

    setup_seq = uart_frame_error_setup_seq::type_id::create("setup_seq");
    bad_seq = uart_bad_frame_seq::type_id::create("bad_seq");
    error_check_seq = uart_frame_error_check_seq::type_id::create("error_check_seq");
    good_seq = uart_good_recovery_seq::type_id::create("good_seq");
    recovery_check_seq = uart_frame_recovery_check_seq::type_id::create("recovery_check_seq");

    setup_seq.start(p_sequencer.apb_seqr);
    bad_seq.start(p_sequencer.uart_seqr);
    error_check_seq.start(p_sequencer.apb_seqr);
    good_seq.start(p_sequencer.uart_seqr);
    recovery_check_seq.start(p_sequencer.apb_seqr);
  endtask
endclass

class uart_rx_fifo_full_vseq extends uart_base_vseq;
  `uvm_object_utils(uart_rx_fifo_full_vseq)

  function new(string name = "uart_rx_fifo_full_vseq");
    super.new(name);
  endfunction

  task body();
    uart_rx_fifo_setup_seq setup_seq;
    uart_rx_fifo_burst_seq burst_seq;
    uart_rx_fifo_drain_seq drain_seq;
    uart_rx_fifo_recovery_uart_seq recovery_uart_seq;
    uart_rx_fifo_recovery_check_seq recovery_check_seq;

    setup_seq = uart_rx_fifo_setup_seq::type_id::create("setup_seq");
    burst_seq = uart_rx_fifo_burst_seq::type_id::create("burst_seq");
    drain_seq = uart_rx_fifo_drain_seq::type_id::create("drain_seq");
    recovery_uart_seq = uart_rx_fifo_recovery_uart_seq::type_id::create("recovery_uart_seq");
    recovery_check_seq = uart_rx_fifo_recovery_check_seq::type_id::create("recovery_check_seq");

    setup_seq.start(p_sequencer.apb_seqr);
    burst_seq.start(p_sequencer.uart_seqr);
    drain_seq.start(p_sequencer.apb_seqr);
    recovery_uart_seq.start(p_sequencer.uart_seqr);
    recovery_check_seq.start(p_sequencer.apb_seqr);
  endtask
endclass

class uart_reset_cdc_vseq extends uart_base_vseq;
  `uvm_object_utils(uart_reset_cdc_vseq)

  function new(string name = "uart_reset_cdc_vseq");
    super.new(name);
  endfunction

  task body();
    uart_reset_midflight_seq midflight_seq;
    uart_reset_defaults_seq defaults_seq;
    uart_reset_preserved_config_seq preserved_seq;
    uart_reset_recovery_seq recovery_seq;

    midflight_seq = uart_reset_midflight_seq::type_id::create("midflight_seq");
    defaults_seq = uart_reset_defaults_seq::type_id::create("defaults_seq");
    preserved_seq = uart_reset_preserved_config_seq::type_id::create("preserved_seq");
    recovery_seq = uart_reset_recovery_seq::type_id::create("recovery_seq");

    midflight_seq.start(p_sequencer.apb_seqr);
    p_sequencer.reset_vif.pulse_both(3, 3);
    defaults_seq.start(p_sequencer.apb_seqr);
    recovery_seq.start(p_sequencer.apb_seqr);

    p_sequencer.reset_vif.pulse_apb_reset(3);
    defaults_seq.start(p_sequencer.apb_seqr);
    recovery_seq.start(p_sequencer.apb_seqr);

    p_sequencer.reset_vif.pulse_uart_reset(3);
    preserved_seq.start(p_sequencer.apb_seqr);
    recovery_seq.start(p_sequencer.apb_seqr);
  endtask
endclass
