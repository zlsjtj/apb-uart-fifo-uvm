class apb_monitor extends uvm_component;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_item) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "apb_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    apb_item tr;

    forever begin
      @(posedge vif.pclk);
      #2ns;
      if (vif.psel && vif.penable && vif.pready) begin
        tr = apb_item::type_id::create("tr", this);
        tr.kind   = vif.pwrite ? apb_item::APB_WRITE : apb_item::APB_READ;
        tr.addr   = vif.paddr;
        tr.data   = vif.pwdata;
        tr.rdata  = vif.prdata;
        tr.slverr = vif.pslverr;
        ap.write(tr);
        `uvm_info("APB_MON", tr.convert2string(), UVM_HIGH)
      end
    end
  endtask
endclass
