class uart_driver extends uvm_driver #(uart_item);
  `uvm_component_utils(uart_driver)

  virtual uart_if vif;
  uvm_analysis_port #(uart_item) ap;

  function new(string name = "uart_driver", uvm_component parent = null);
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

    vif.idle_line();
    wait (vif.uart_rst_n == 1'b1);

    forever begin
      seq_item_port.get_next_item(tr);
      drive_frame(tr);
      ap.write(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_frame(uart_item tr);
    repeat (tr.gap_cycles) begin
      @(vif.drv_cb);
      vif.drv_cb.rx_i <= 1'b1;
    end

    @(vif.drv_cb);
    vif.drv_cb.rx_i <= 1'b0;

    for (int i = 0; i < 8; i++) begin
      @(vif.drv_cb);
      vif.drv_cb.rx_i <= tr.data[i];
    end

    @(vif.drv_cb);
    vif.drv_cb.rx_i <= 1'b1;

    @(vif.drv_cb);
    vif.drv_cb.rx_i <= 1'b1;

    `uvm_info("UART_DRV", tr.convert2string(), UVM_HIGH)
  endtask
endclass
