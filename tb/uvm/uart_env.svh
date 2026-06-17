class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  apb_agent       apb;
  uart_agent      uart;
  uart_scoreboard sb;
  uart_coverage   cov;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb  = apb_agent::type_id::create("apb", this);
    uart = uart_agent::type_id::create("uart", this);
    sb   = uart_scoreboard::type_id::create("sb", this);
    cov  = uart_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb.mon.ap.connect(sb.apb_export);
    uart.mon.ap.connect(sb.tx_export);
    uart.drv.ap.connect(sb.rx_export);

    apb.mon.ap.connect(cov.apb_export);
    uart.mon.ap.connect(cov.uart_export);
  endfunction
endclass
