class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  apb_agent       apb;
  uart_agent      uart;
  uart_scoreboard sb;
  uart_predictor  pred;
  uart_coverage   cov;
  uart_env_cfg    cfg;
  uart_virtual_sequencer vseqr;
  uart_reg_block  regmodel;
  uart_apb_reg_adapter reg_adapter;
  uvm_reg_predictor #(apb_item) reg_predictor;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal("NOCFG", "uart_env_cfg is not set")
    end
    cfg.validate();
    apb  = apb_agent::type_id::create("apb", this);
    uart = uart_agent::type_id::create("uart", this);
    sb   = uart_scoreboard::type_id::create("sb", this);
    pred = uart_predictor::type_id::create("pred", this);
    cov  = uart_coverage::type_id::create("cov", this);
    vseqr = uart_virtual_sequencer::type_id::create("vseqr", this);
    regmodel = uart_reg_block::type_id::create("regmodel");
    regmodel.configure(null, "");
    regmodel.build();
    regmodel.lock_model();
    regmodel.reset();
    reg_adapter = uart_apb_reg_adapter::type_id::create("reg_adapter");
    reg_predictor = uvm_reg_predictor#(apb_item)::type_id::create("reg_predictor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb.mon.ap.connect(sb.apb_export);
    uart.mon.ap.connect(sb.tx_export);
    apb.mon.ap.connect(pred.apb_export);
    uart.mon.ap.connect(pred.tx_export);
    uart.rx_mon.ap.connect(pred.rx_line_export);
    uart.cfg_mon.ap.connect(pred.cfg_export);
    pred.exp_tx_ap.connect(sb.exp_tx_export);
    pred.exp_rx_ap.connect(sb.exp_rx_export);

    apb.mon.ap.connect(cov.apb_export);
    uart.mon.ap.connect(cov.uart_export);

    regmodel.default_map.set_sequencer(apb.seqr, reg_adapter);
    regmodel.default_map.set_auto_predict(0);
    reg_predictor.map = regmodel.default_map;
    reg_predictor.adapter = reg_adapter;
    apb.mon.ap.connect(reg_predictor.bus_in);

    vseqr.apb_seqr = apb.seqr;
    vseqr.uart_seqr = uart.seqr;
  endfunction
endclass
