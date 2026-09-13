// Optional white-box diagnostic consumer, deliberately outside uart_agent.
// It does not update serial_cfg or generate expected TX/RX data.
class uart_config_checker extends uvm_subscriber #(uart_cfg_item);
  `uvm_component_utils(uart_config_checker)
  int unsigned events;
  time last_apply;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void write(uart_cfg_item t);
    if (t.baud < UART_BAUD_MIN || (events != 0 && t.effective_time <= last_apply))
      `uvm_error("CFG_EVENT", "Invalid normalized baud or duplicate configuration event")
    events++;
    last_apply = t.effective_time;
  endfunction
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    if (events == 0) `uvm_error("CFG_EVENT", "Enabled white-box monitor published no configuration event")
    `uvm_info("CFG_EVENT_SUMMARY", $sformatf("observed %0d apply events", events), UVM_LOW)
  endfunction
endclass
