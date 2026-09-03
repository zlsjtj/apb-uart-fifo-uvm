class uart_config_monitor extends uvm_component;
  `uvm_component_utils(uart_config_monitor)

  virtual uart_probe_if probe_vif;
  uvm_analysis_port #(uart_cfg_item) ap;

  function new(string name = "uart_config_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_probe_if)::get(this, "", "probe_vif", probe_vif)) begin
      `uvm_fatal("NOPROBEVIF", "uart_probe_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_cfg_item tr;

    forever begin
      @(probe_vif.uart_mon_cb);
      if (probe_vif.uart_mon_cb.uart_clk_rst_n && probe_vif.uart_mon_cb.cfg_apply_uart) begin
        tr = uart_cfg_item::type_id::create("cfg_tr", this);
        tr.ctrl = probe_vif.uart_mon_cb.ctrl_uart_cfg;
        tr.baud = probe_vif.uart_mon_cb.baud_uart_cfg;
        tr.effective_time = $time;
        ap.write(tr);
        `uvm_info("UART_CFG_MON",
                  $sformatf("UART-domain config applied ctrl=0x%0h baud=%0d at %0t",
                            tr.ctrl, tr.baud, tr.effective_time), UVM_HIGH)
      end
    end
  endtask
endclass
