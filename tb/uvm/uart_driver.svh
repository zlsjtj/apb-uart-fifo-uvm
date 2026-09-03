class uart_driver extends uvm_driver #(uart_item);
  `uvm_component_utils(uart_driver)

  virtual uart_if vif;
  uart_env_cfg cfg;

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "uart_if is not set")
    end
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal("NOCFG", "uart_env_cfg is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_item tr;

    vif.idle_line();
    wait (vif.uart_rst_n == 1'b1);
    // Match the DUT's two-stage synchronous reset release in uart_clk.
    repeat (3) @(posedge vif.uart_clk);

    forever begin
      seq_item_port.get_next_item(tr);
      drive_frame(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_frame(uart_item tr);
    time bit_period;

    if (tr.bit_cycles == 0) begin
      `uvm_fatal("BAD_UART_ITEM", "bit_cycles must be non-zero")
    end
    bit_period = tr.bit_cycles * (2 * cfg.uart_half_ns) * 1ns;

    // Re-anchor every frame to the public UART clock before applying the
    // independently selected edge offset. This avoids cumulative phase drift
    // across long bursts while still keeping the BFM independent of DUT timing pulses.
    repeat (tr.gap_cycles * tr.bit_cycles) @(posedge vif.uart_clk);
    #(tr.edge_offset_ps * 1ps);

    vif.rx_i <= 1'b0;
    #(bit_period);

    for (int i = 0; i < UART_DATA_BITS; i++) begin
      vif.rx_i <= tr.data[i];
      #(bit_period);
    end

    vif.rx_i <= tr.frame_err ? 1'b0 : 1'b1;
    #(bit_period);

    // Return to the idle level after the stop-bit interval. This also keeps a
    // deliberately bad stop bit from being mistaken for a second start bit.
    vif.rx_i <= 1'b1;
    #(bit_period);

    `uvm_info("UART_DRV", tr.convert2string(), UVM_HIGH)
  endtask

endclass
