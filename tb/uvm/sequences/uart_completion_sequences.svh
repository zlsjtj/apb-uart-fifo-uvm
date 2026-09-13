class uart_tx_completion_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_tx_completion_seq)
  virtual uart_if vif;
  uart_env_cfg cfg;
  function new(string name="uart_tx_completion_seq"); super.new(name); endfunction

  task send_one(int unsigned baud, bit [7:0] value, bit check_stop);
    bit [31:0] status, data;
    bit err;
    realtime start_time, bit_period, stop_check;
    bit started;
    wait_tx_idle();
    apb_write(ADDR_BAUD, baud);
    apb_write(ADDR_CTRL, 3);
    bit_period = 2 * cfg.uart_half_ns * baud * 1ns;
    started = 0;
    fork
      begin
        // Use the public falling start edge, never a DUT tick or FSM probe.
        fork
          begin @(negedge vif.tx_o); start_time=$realtime; started=1; end
          begin #100us; end
        join_any
        disable fork;
        if (!started) `uvm_fatal("TX_START_TIMEOUT", "No public TX start edge")
      end
      begin
        apb_write_status(ADDR_TXDATA, value, 0, err);
        if (err) `uvm_error("TX_COMPLETION", "Unexpected TXDATA rejection")
        apb_read(ADDR_STATUS, status);
        if ((!started || $realtime < start_time+10*bit_period) && !status[UART_STATUS_TX_BUSY_BIT])
          `uvm_error("TX_COMPLETION", "TX_BUSY missing immediately after accepted write")
      end
    join
    if (check_stop) begin
      // Test within the last stop bit, leaving ample time for the APB read.
      stop_check = start_time + 9.5 * bit_period;
      if ($realtime < stop_check) #(stop_check-$realtime);
      apb_read(ADDR_STATUS, status);
      if (!status[UART_STATUS_TX_BUSY_BIT] || !status[UART_STATUS_TX_EMPTY_BIT])
        `uvm_error("TX_COMPLETION", "FIFO empty must still be busy during the final stop bit")
    end
    wait_tx_idle();
    if ($realtime < start_time + 10 * bit_period)
      `uvm_error("TX_COMPLETION", "Completion was reported before the complete stop bit")
    apb_read_status(ADDR_RXDATA, data, 0, err);
    if (err || data[7:0] != value)
      `uvm_error("TX_COMPLETION", "Loopback data mismatch after completion")
  endtask

  task body();
    int unsigned slow_baud;
    if (!uvm_config_db#(virtual uart_if)::get(null,"uvm_test_top","timing_vif",vif) ||
        !uvm_config_db#(uart_env_cfg)::get(m_sequencer,"","env_cfg",cfg))
      `uvm_fatal("NOCFG", "Completion sequence needs public timing interface and clock configuration")
    slow_baud = (20*cfg.pclk_half_ns + 2*cfg.uart_half_ns-1)/(2*cfg.uart_half_ns);
    if (slow_baud<20) slow_baud=20;
    send_one(slow_baud, 8'h55, 1);
    send_one(1, 8'hc3, 0);
    send_one(4, 8'ha6, 0);
    `uvm_info("TX_COMPLETION", "Immediate busy, full stop bit and adjacent baud changes checked", UVM_LOW)
  endtask
endclass

class uart_fifo_wrap_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_fifo_wrap_seq)
  function new(string name="uart_fifo_wrap_seq"); super.new(name); endfunction
  task body();
    bit [31:0] data, status;
    bit err;
    bit [7:0] expected;
    apb_write(ADDR_BAUD, 1);
    apb_write(ADDR_CTRL, 3);
    // Sequential round trips cover more than two complete pointer moduli.
    // Dedicated full tests separately exercise simultaneous queued traffic.
    for (int n=0; n<4*fifo_depth()+3; n++) begin
      expected = $urandom_range(0,255);
      apb_write_status(ADDR_TXDATA, expected, 0, err);
      if (err) `uvm_error("FIFO_WRAP", "Unexpected TX rejection during round trip")
      wait_tx_idle();
      apb_read_status(ADDR_RXDATA, data, 0, err);
      if (err || data[7:0] != expected)
        `uvm_error("FIFO_WRAP", $sformatf("depth=%0d index=%0d got=%02h expected=%02h",fifo_depth(),n,data,expected))
    end
    apb_read(ADDR_STATUS,status);
    if (status[UART_STATUS_TX_BUSY_BIT] || !status[UART_STATUS_RX_EMPTY_BIT])
      `uvm_error("FIFO_WRAP", "Round trips did not drain both directions")
    `uvm_info("FIFO_WRAP", $sformatf("depth=%0d round trips=%0d",fifo_depth(),4*fifo_depth()+3),UVM_LOW)
  endtask
endclass
