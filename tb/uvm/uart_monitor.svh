class uart_monitor extends uvm_component;
  `uvm_component_utils(uart_monitor)

  virtual uart_if vif;
  uart_serial_cfg serial_cfg;
  int unsigned aborted_frames;
  uvm_analysis_port #(uart_item) ap;

  function new(string name = "uart_monitor", uvm_component parent = null);
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
    bit prev_tx;
    bit [2:0] frame_ctrl;
    bit [31:0] frame_baud;
    int unsigned divisor;
    int unsigned epoch;
    bit aborted;

    prev_tx = 1'b1;
    forever begin
      @(vif.mon_cb);
      if (!vif.uart_rst_n) begin
        prev_tx = 1'b1;
      end else if ((prev_tx == 1'b1) && (vif.mon_cb.tx_o == 1'b0)) begin
        if (!serial_cfg.ready) begin
          `uvm_error("UART_CFG_UNSETTLED", "Frame started before public STATUS not-busy observation")
          prev_tx = vif.mon_cb.tx_o;
          continue;
        end
        if (!serial_cfg.ctrl[UART_CTRL_ENABLE_BIT]) begin
          prev_tx = vif.mon_cb.tx_o;
          continue;
        end
        tr = uart_item::type_id::create("tr", this);
        // Normal software changes configuration only between frames. Freeze
        // the public configuration so an illegal mid-frame change cannot
        // silently change the checker along with the DUT.
        serial_cfg.snapshot(frame_ctrl, frame_baud);
        divisor = (frame_baud == 0) ? UART_BAUD_MIN : frame_baud;
        epoch = serial_cfg.reset_epoch;
        aborted = 1'b0;

        for (int i = 0; i < UART_DATA_BITS; i++) begin
          wait_uart_cycles(divisor, epoch, aborted);
          if (aborted) break;
          tr.data[i] = vif.mon_cb.tx_o;
        end

        if (!aborted) wait_uart_cycles(divisor, epoch, aborted);
        if (aborted) begin
          aborted_frames++;
          prev_tx = 1'b1;
          continue;
        end
        tr.frame_err = (vif.mon_cb.tx_o != 1'b1);
        ap.write(tr);
        `uvm_info("UART_MON", tr.convert2string(), UVM_HIGH)
      end
      prev_tx = vif.mon_cb.tx_o;
    end
  endtask

  task wait_uart_cycles(int unsigned cycles, int unsigned epoch, output bit aborted);
    aborted = 1'b0;
    repeat (cycles) begin
      @(vif.mon_cb);
      if (!vif.uart_rst_n || serial_cfg.reset_epoch != epoch) begin
        aborted = 1'b1;
        return;
      end
    end
  endtask
endclass
