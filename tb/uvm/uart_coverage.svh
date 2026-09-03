class uart_coverage extends uvm_component;
  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp_apb_cov  #(apb_item,  uart_coverage) apb_export;
  uvm_analysis_imp_uart_cov #(uart_item, uart_coverage) uart_export;
  virtual reset_if reset_vif;

  bit [7:0]  cov_addr;
  bit        cov_write;
  bit        cov_slverr;
  bit [7:0]  cov_data;
  bit        cov_irq_en;
  bit        cov_status_rx_full;
  bit        cov_status_rx_empty;
  bit        cov_status_irq;
  bit        cov_status_frame_err;
  bit [1:0]  cov_reset_kind;

  covergroup apb_cg;
    option.per_instance = 1;

    cp_addr: coverpoint cov_addr {
      bins ctrl   = {UART_ADDR_CTRL};
      bins status = {UART_ADDR_STATUS};
      bins baud   = {UART_ADDR_BAUD};
      bins txdata = {UART_ADDR_TXDATA};
      bins rxdata = {UART_ADDR_RXDATA};
      bins bad    = default;
    }

    cp_kind: coverpoint cov_write {
      bins read  = {0};
      bins write = {1};
    }

    cp_err: coverpoint cov_slverr {
      bins ok  = {0};
      bins err = {1};
    }

    cp_data: coverpoint cov_data {
      bins zero = {8'h00};
      bins ff   = {8'hff};
      bins low  = {[8'h01:8'h3f]};
      bins mid  = {[8'h40:8'hbf]};
      bins high = {[8'hc0:8'hfe]};
    }

    cross cp_addr, cp_kind;
    cross_addr_err: cross cp_addr, cp_err {
      ignore_bins legal_register_errors =
        (binsof(cp_addr.ctrl) || binsof(cp_addr.baud)) && binsof(cp_err.err);
    }
  endgroup

  covergroup uart_cg;
    option.per_instance = 1;
    cp_uart_data: coverpoint cov_data {
      bins zero = {8'h00};
      bins ff   = {8'hff};
      bins low  = {[8'h01:8'h3f]};
      bins mid  = {[8'h40:8'hbf]};
      bins high = {[8'hc0:8'hfe]};
    }
  endgroup

  covergroup status_irq_cg;
    option.per_instance = 1;

    cp_irq_state: coverpoint {cov_irq_en, cov_status_rx_empty, cov_status_irq} {
      bins disabled_empty   = {3'b010};
      bins disabled_pending = {3'b000};
      bins enabled_empty    = {3'b110};
      bins enabled_pending  = {3'b101};
    }

    cp_irq_transition: coverpoint cov_status_irq {
      bins asserted = (0 => 1);
      bins cleared  = (1 => 0);
    }
  endgroup

  covergroup status_error_cg;
    option.per_instance = 1;

    cp_error_state: coverpoint {cov_status_frame_err,
                                cov_status_irq,
                                cov_status_rx_empty} {
      bins clean_empty       = {3'b001};
      bins bad_frame_rejected = {3'b101};
      bins recovered_pending = {3'b010};
    }

    cp_error_transition: coverpoint cov_status_frame_err {
      bins detected = (0 => 1);
      bins cleared  = (1 => 0);
    }
  endgroup

  covergroup status_fifo_cg;
    option.per_instance = 1;

    cp_rx_fifo_state: coverpoint {cov_status_rx_full,
                                  cov_status_rx_empty,
                                  cov_status_irq} {
      bins empty           = {3'b010};
      bins partial_pending = {3'b001};
      bins full_pending    = {3'b101};
    }

    cp_rx_full_transition: coverpoint cov_status_rx_full {
      bins filled  = (0 => 1);
      bins drained = (1 => 0);
    }
  endgroup

  covergroup reset_cg;
    option.per_instance = 1;

    cp_reset_kind: coverpoint cov_reset_kind {
      bins apb_only  = {2'b10};
      bins uart_only = {2'b01};
      bins both      = {2'b11};
    }
  endgroup

  function new(string name = "uart_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_export  = new("apb_export", this);
    uart_export = new("uart_export", this);
    apb_cg      = new();
    uart_cg     = new();
    status_irq_cg = new();
    status_error_cg = new();
    status_fifo_cg = new();
    reset_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(negedge reset_vif.presetn or negedge reset_vif.uart_rst_n);
      #1ps;
      cov_reset_kind = {!reset_vif.presetn, !reset_vif.uart_rst_n};
      reset_cg.sample();
      wait (reset_vif.presetn && reset_vif.uart_rst_n);
    end
  endtask

  function void write_apb_cov(apb_item tr);
    cov_addr   = tr.addr;
    cov_write  = (tr.kind == apb_item::APB_WRITE);
    cov_slverr = tr.slverr;
    cov_data   = (tr.kind == apb_item::APB_WRITE) ? tr.data[7:0] : tr.rdata[7:0];
    apb_cg.sample();

    if (tr.addr == UART_ADDR_CTRL && tr.kind == apb_item::APB_WRITE && !tr.slverr) begin
      cov_irq_en = tr.data[UART_CTRL_IRQ_EN_BIT];
    end

    if (tr.addr == UART_ADDR_STATUS && tr.kind == apb_item::APB_READ && !tr.slverr) begin
      cov_status_rx_full  = tr.rdata[UART_STATUS_RX_FULL_BIT];
      cov_status_rx_empty = tr.rdata[UART_STATUS_RX_EMPTY_BIT];
      cov_status_irq      = tr.rdata[UART_STATUS_IRQ_BIT];
      cov_status_frame_err = tr.rdata[UART_STATUS_FRAME_ERR_BIT];
      status_irq_cg.sample();
      status_error_cg.sample();
      status_fifo_cg.sample();
    end
  endfunction

  function void write_uart_cov(uart_item tr);
    cov_data = tr.data;
    uart_cg.sample();
  endfunction
endclass
