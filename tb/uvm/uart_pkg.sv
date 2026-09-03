package uart_pkg;
  import uvm_pkg::*;
  import apb_uart_reg_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_apb_sb)
  `uvm_analysis_imp_decl(_tx_sb)
  `uvm_analysis_imp_decl(_exp_tx_sb)
  `uvm_analysis_imp_decl(_exp_rx_sb)
  `uvm_analysis_imp_decl(_apb_pred)
  `uvm_analysis_imp_decl(_tx_pred)
  `uvm_analysis_imp_decl(_rx_line_pred)
  `uvm_analysis_imp_decl(_reset_pred)
  `uvm_analysis_imp_decl(_reset_sb)
  `uvm_analysis_imp_decl(_reset_cov)
  `uvm_analysis_imp_decl(_reset_ral)
  `uvm_analysis_imp_decl(_apb_cov)
  `uvm_analysis_imp_decl(_uart_cov)

  `include "uart_env_cfg.svh"
  `include "uart_serial_cfg.svh"
  `include "apb_item.svh"
  `include "uart_reg_model.svh"
  `include "uart_reset_monitor.svh"
  `include "uart_item.svh"
  `include "apb_sequencer.svh"
  `include "apb_driver.svh"
  `include "apb_monitor.svh"
  `include "apb_agent.svh"
  `include "uart_sequencer.svh"
  `include "uart_virtual_sequencer.svh"
  `include "uart_driver.svh"
  `include "uart_monitor.svh"
  `include "uart_rx_monitor.svh"
  `include "uart_config_monitor.svh"
  `include "uart_agent.svh"
  `include "uart_predictor.svh"
  `include "uart_scoreboard.svh"
  `include "uart_coverage.svh"
  `include "uart_env.svh"
  `include "uart_sequences.svh"
  `include "uart_virtual_sequences.svh"
  `include "uart_tests.svh"
endpackage
