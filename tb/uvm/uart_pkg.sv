package uart_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_apb_sb)
  `uvm_analysis_imp_decl(_tx_sb)
  `uvm_analysis_imp_decl(_rx_sb)
  `uvm_analysis_imp_decl(_apb_cov)
  `uvm_analysis_imp_decl(_uart_cov)

  `include "apb_item.svh"
  `include "uart_item.svh"
  `include "apb_sequencer.svh"
  `include "apb_driver.svh"
  `include "apb_monitor.svh"
  `include "apb_agent.svh"
  `include "uart_sequencer.svh"
  `include "uart_driver.svh"
  `include "uart_monitor.svh"
  `include "uart_agent.svh"
  `include "uart_scoreboard.svh"
  `include "uart_coverage.svh"
  `include "uart_env.svh"
endpackage
