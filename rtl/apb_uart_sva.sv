module apb_uart_sva (
  input logic        pclk,
  input logic        presetn,
  input logic        uart_clk,
  input logic        uart_rst_n,
  input logic        pclk_rst_n,
  input logic        uart_clk_rst_n,
  input logic        fifo_async_rst_n,
  input logic        fifo_pclk_rst_n,
  input logic        fifo_uart_rst_n,
  input logic        psel,
  input logic        penable,
  input logic        pwrite,
  input logic [7:0]  paddr,
  input logic [31:0] pwdata,
  input logic        pready,
  input logic        pslverr,
  input logic        cfg_busy,
  input logic        cfg_req_tgl,
  input logic        cfg_ack_pclk_q2,
  input logic        cfg_uart_initialized,
  input logic        cfg_apply_uart,
  input logic [2:0]  ctrl_uart_cfg,
  input logic [31:0] baud_uart_cfg,
  input logic        enable_uart,
  input logic        irq_en,
  input logic        tx_full,
  input logic        tx_push,
  input logic        rx_full,
  input logic        rx_full_pclk,
  input logic        rx_empty,
  input logic        rx_pop,
  input logic        rx_frame_err,
  input logic        rx_frame_err_pclk,
  input logic        rx_wr_en,
  input logic        irq_o
);
  import apb_uart_reg_pkg::*;

  logic legal_addr;
  assign legal_addr = uart_addr_is_legal(paddr);

  apb_setup_to_access:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && !penable) |=> (psel && penable));

  apb_access_has_ready:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable) |-> pready);

  apb_addr_stable_in_access:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && !penable) |=> $stable(paddr));

  invalid_addr_reports_error:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && !legal_addr) |=> pslverr);

  status_write_reports_error:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_STATUS) |=> pslverr);

  rejected_tx_write_reports_error:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_TXDATA &&
       (!enable_uart || tx_full)) |=> pslverr);

  rejected_tx_write_has_no_push:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_TXDATA &&
       (!enable_uart || tx_full)) |-> !tx_push);

  accepted_tx_write_pushes:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_TXDATA &&
       enable_uart && !tx_full) |-> tx_push);

  empty_rx_read_reports_error:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && !pwrite && paddr == UART_ADDR_RXDATA && rx_empty)
      |=> pslverr);

  rx_write_reports_error:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_RXDATA) |=> pslverr);

  rejected_rx_access_has_no_pop:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && paddr == UART_ADDR_RXDATA && (pwrite || rx_empty))
      |-> !rx_pop);

  invalid_addr_has_no_fifo_side_effect:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && !legal_addr) |-> (!tx_push && !rx_pop));

  baud_div_not_zero_after_write:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      (psel && penable && pwrite && paddr == UART_ADDR_BAUD && pwdata == 0) |=> !pslverr);

  config_mailbox_idle_matches_ack:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      !cfg_busy |-> (cfg_req_tgl == cfg_ack_pclk_q2));

  config_payload_known:
    assert property (@(posedge uart_clk) disable iff (!fifo_uart_rst_n)
      cfg_uart_initialized |-> !$isunknown({ctrl_uart_cfg, baud_uart_cfg}));

  config_changes_only_on_apply:
    assert property (@(posedge uart_clk) disable iff (!fifo_uart_rst_n)
      ($changed(ctrl_uart_cfg) || $changed(baud_uart_cfg)) |-> cfg_apply_uart);

  config_apply_payload_known:
    assert property (@(posedge uart_clk) disable iff (!fifo_uart_rst_n)
      cfg_apply_uart |-> !$isunknown({ctrl_uart_cfg, baud_uart_cfg}));

  status_cdc_flags_known:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      !$isunknown({rx_full_pclk, rx_frame_err_pclk}));

  irq_is_known:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      !$isunknown(irq_o));

  irq_matches_rx_state:
    assert property (@(posedge pclk) disable iff (!pclk_rst_n)
      irq_o == (irq_en && !rx_empty));

  irq_asserted_with_pending_rx:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      !irq_o ##1 irq_o);

  irq_cleared:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      irq_o ##1 !irq_o);

  disabled_tx_write_rejected:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      psel && penable && pwrite && paddr == UART_ADDR_TXDATA && !enable_uart);

  full_tx_write_rejected:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      psel && penable && pwrite && paddr == UART_ADDR_TXDATA && tx_full);

  empty_rx_read_rejected:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      psel && penable && !pwrite && paddr == UART_ADDR_RXDATA && rx_empty);

  rx_write_rejected:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      psel && penable && pwrite && paddr == UART_ADDR_RXDATA);

  config_mailbox_exercised:
    cover property (@(posedge pclk) disable iff (!pclk_rst_n)
      cfg_busy ##[1:32] !cfg_busy);

  config_uart_apply_seen:
    cover property (@(posedge uart_clk) disable iff (!fifo_uart_rst_n)
      cfg_apply_uart);

  bad_frame_not_written:
    assert property (@(posedge uart_clk) disable iff (!uart_clk_rst_n)
      rx_frame_err |-> !rx_wr_en);

  frame_error_seen:
    cover property (@(posedge uart_clk) disable iff (!uart_clk_rst_n)
      rx_frame_err);

  rx_full_blocks_write:
    assert property (@(posedge uart_clk) disable iff (!uart_clk_rst_n)
      rx_full |-> !rx_wr_en);

  rx_fifo_reaches_full:
    cover property (@(posedge uart_clk) disable iff (!uart_clk_rst_n)
      !rx_full ##1 rx_full);

  pclk_reset_asserts_with_source:
    assert property (@(posedge pclk)
      !presetn |-> !pclk_rst_n);

  uart_reset_asserts_with_source:
    assert property (@(posedge uart_clk)
      !uart_rst_n |-> !uart_clk_rst_n);

  fifo_pclk_reset_asserts_with_source:
    assert property (@(posedge pclk)
      !fifo_async_rst_n |-> !fifo_pclk_rst_n);

  fifo_uart_reset_asserts_with_source:
    assert property (@(posedge uart_clk)
      !fifo_async_rst_n |-> !fifo_uart_rst_n);

  pclk_reset_releases_only_when_source_high:
    assert property (@(posedge pclk)
      $rose(pclk_rst_n) |-> presetn);

  uart_reset_releases_only_when_source_high:
    assert property (@(posedge uart_clk)
      $rose(uart_clk_rst_n) |-> uart_rst_n);

  fifo_pclk_reset_releases_only_when_sources_high:
    assert property (@(posedge pclk)
      $rose(fifo_pclk_rst_n) |-> (presetn && uart_rst_n));

  fifo_uart_reset_releases_only_when_sources_high:
    assert property (@(posedge uart_clk)
      $rose(fifo_uart_rst_n) |-> (presetn && uart_rst_n));

  pclk_reset_release_seen:
    cover property (@(posedge pclk) $rose(pclk_rst_n));

  uart_reset_release_seen:
    cover property (@(posedge uart_clk) $rose(uart_clk_rst_n));

  fifo_pclk_reset_release_seen:
    cover property (@(posedge pclk) $rose(fifo_pclk_rst_n));

  fifo_uart_reset_release_seen:
    cover property (@(posedge uart_clk) $rose(fifo_uart_rst_n));

endmodule
