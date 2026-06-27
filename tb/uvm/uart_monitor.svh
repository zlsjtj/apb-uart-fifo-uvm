class uart_monitor extends uvm_component;
  `uvm_component_utils(uart_monitor)

  virtual uart_if vif;
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
  endfunction

  task run_phase(uvm_phase phase);
    uart_item tr;

    forever begin
      @(vif.mon_cb);
      if (vif.uart_rst_n && vif.mon_cb.bit_tick && vif.mon_cb.tx_o == 1'b0) begin
        tr = uart_item::type_id::create("tr", this);

        for (int i = 0; i < 8; i++) begin
          wait_tick();
          tr.data[i] = vif.mon_cb.tx_o;
        end

        wait_tick();
        tr.frame_err = (vif.mon_cb.tx_o != 1'b1);
        ap.write(tr);
        `uvm_info("UART_MON", tr.convert2string(), UVM_HIGH)
      end
    end
  endtask

  task wait_tick();
    do begin
      @(vif.mon_cb);
    end while (!vif.mon_cb.bit_tick);
  endtask
endclass
