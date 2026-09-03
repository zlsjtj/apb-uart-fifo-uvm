class uart_monitor extends uvm_component;
  `uvm_component_utils(uart_monitor)

  virtual uart_if vif;
  virtual uart_probe_if probe_vif;
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
    if (!uvm_config_db#(virtual uart_probe_if)::get(this, "", "probe_vif", probe_vif)) begin
      `uvm_fatal("NOPROBEVIF", "uart_probe_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_item tr;
    bit prev_tx;
    int unsigned divisor;

    prev_tx = 1'b1;
    forever begin
      @(vif.mon_cb);
      if (!vif.uart_rst_n || !probe_vif.uart_mon_cb.ctrl_uart_cfg[UART_CTRL_ENABLE_BIT]) begin
        prev_tx = 1'b1;
      end else if ((prev_tx == 1'b1) && (vif.mon_cb.tx_o == 1'b0)) begin
        tr = uart_item::type_id::create("tr", this);
        divisor = effective_divisor(probe_vif.uart_mon_cb.baud_uart_cfg);

        for (int i = 0; i < UART_DATA_BITS; i++) begin
          wait_uart_cycles(divisor);
          tr.data[i] = vif.mon_cb.tx_o;
        end

        wait_uart_cycles(divisor);
        tr.frame_err = (vif.mon_cb.tx_o != 1'b1);
        ap.write(tr);
        `uvm_info("UART_MON", tr.convert2string(), UVM_HIGH)
      end
      prev_tx = vif.mon_cb.tx_o;
    end
  endtask

  function int unsigned effective_divisor(logic [31:0] baud);
    return (baud == 0) ? 1 : baud;
  endfunction

  task wait_uart_cycles(int unsigned cycles);
    repeat (cycles) @(vif.mon_cb);
  endtask
endclass
