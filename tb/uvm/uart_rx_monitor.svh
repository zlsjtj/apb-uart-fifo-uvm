class uart_rx_monitor extends uvm_component;
  `uvm_component_utils(uart_rx_monitor)

  virtual uart_if vif;
  uart_serial_cfg serial_cfg;
  uvm_analysis_port #(uart_item) ap;

  function new(string name = "uart_rx_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "uart_if is not set")
    end
    if (!uvm_config_db#(uart_serial_cfg)::get(this, "", "serial_cfg", serial_cfg)) begin
      `uvm_fatal("NOSERIALCFG", "uart_serial_cfg is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_item tr;
    bit prev_rx;
    bit [2:0] frame_ctrl;
    bit [31:0] frame_baud;
    int unsigned divisor;

    prev_rx = 1'b1;
    forever begin
      @(vif.mon_cb);
      if (!vif.uart_rst_n || !serial_cfg.ctrl[UART_CTRL_ENABLE_BIT]) begin
        prev_rx = 1'b1;
      end else if ((prev_rx == 1'b1) && (vif.mon_cb.rx_i == 1'b0)) begin
        tr = uart_item::type_id::create("rx_pin_tr", this);
        // Decode the complete frame with the configuration visible when its
        // start edge was observed, even if software writes BAUD mid-frame.
        serial_cfg.snapshot(frame_ctrl, frame_baud);
        divisor = (frame_baud == 0) ? UART_BAUD_MIN : frame_baud;

        for (int i = 0; i < UART_DATA_BITS; i++) begin
          wait_uart_cycles(divisor);
          tr.data[i] = vif.mon_cb.rx_i;
        end

        wait_uart_cycles(divisor);
        tr.frame_err = (vif.mon_cb.rx_i != 1'b1);
        ap.write(tr);
        `uvm_info("UART_RX_MON", tr.convert2string(), UVM_HIGH)
      end
      prev_rx = vif.mon_cb.rx_i;
    end
  endtask

  task wait_uart_cycles(int unsigned cycles);
    repeat (cycles) @(vif.mon_cb);
  endtask
endclass
