class uart_coverage extends uvm_component;
  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp_apb_cov  #(apb_item,  uart_coverage) apb_export;
  uvm_analysis_imp_uart_cov #(uart_item, uart_coverage) uart_export;

  bit [7:0]  cov_addr;
  bit        cov_write;
  bit        cov_slverr;
  bit [7:0]  cov_data;

  covergroup apb_cg;
    option.per_instance = 1;

    cp_addr: coverpoint cov_addr {
      bins ctrl   = {8'h00};
      bins status = {8'h04};
      bins baud   = {8'h08};
      bins txdata = {8'h0c};
      bins rxdata = {8'h10};
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
    cross cp_addr, cp_err;
  endgroup

  covergroup uart_cg;
    option.per_instance = 1;
    cp_uart_data: coverpoint cov_data {
      bins zero = {8'h00};
      bins ff   = {8'hff};
      bins misc[] = {[8'h01:8'hfe]};
    }
  endgroup

  function new(string name = "uart_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_export  = new("apb_export", this);
    uart_export = new("uart_export", this);
    apb_cg      = new();
    uart_cg     = new();
  endfunction

  function void write_apb_cov(apb_item tr);
    cov_addr   = tr.addr;
    cov_write  = (tr.kind == apb_item::APB_WRITE);
    cov_slverr = tr.slverr;
    cov_data   = (tr.kind == apb_item::APB_WRITE) ? tr.data[7:0] : tr.rdata[7:0];
    apb_cg.sample();
  endfunction

  function void write_uart_cov(uart_item tr);
    cov_data = tr.data;
    uart_cg.sample();
  endfunction
endclass
