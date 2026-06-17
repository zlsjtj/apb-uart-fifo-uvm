class apb_driver extends uvm_driver #(apb_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "apb_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    apb_item tr;

    vif.idle_bus();
    wait (vif.presetn == 1'b1);

    forever begin
      seq_item_port.get_next_item(tr);
      drive_one(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_one(apb_item tr);
    repeat (tr.idle_cycles) begin
      @(posedge vif.pclk);
    end

    @(negedge vif.pclk);
    vif.paddr   <= tr.addr;
    vif.pwrite  <= (tr.kind == apb_item::APB_WRITE);
    vif.pwdata  <= tr.data;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    @(negedge vif.pclk);
    vif.penable <= 1'b1;

    do begin
      @(posedge vif.pclk);
    end while (vif.pready !== 1'b1);

    #2ns;
    tr.rdata  = vif.prdata;
    tr.slverr = vif.pslverr;

    @(negedge vif.pclk);
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.paddr   <= '0;
    vif.pwdata  <= '0;

    `uvm_info("APB_DRV", tr.convert2string(), UVM_HIGH)
  endtask
endclass
