typedef enum bit [1:0] {
  UART_RESET_NONE = 2'b00,
  UART_RESET_UART = 2'b01,
  UART_RESET_APB  = 2'b10,
  UART_RESET_BOTH = 2'b11
} uart_reset_kind_e;

class uart_reset_item extends uvm_sequence_item;
  `uvm_object_utils(uart_reset_item)

  uart_reset_kind_e kind;
  bit asserted;
  time observed_time;

  function new(string name = "uart_reset_item");
    super.new(name);
  endfunction
endclass

class uart_reset_monitor extends uvm_component;
  `uvm_component_utils(uart_reset_monitor)

  virtual reset_if vif;
  uvm_analysis_port #(uart_reset_item) ap;

  function new(string name = "uart_reset_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    bit old_presetn;
    bit old_uart_rst_n;
    bit new_presetn;
    bit new_uart_rst_n;
    uart_reset_item tr;

    old_presetn = vif.presetn;
    old_uart_rst_n = vif.uart_rst_n;
    forever begin
      @(vif.presetn or vif.uart_rst_n);
      #1ps;
      new_presetn = vif.presetn;
      new_uart_rst_n = vif.uart_rst_n;

      if ((old_presetn && !new_presetn) ||
          (old_uart_rst_n && !new_uart_rst_n)) begin
        tr = uart_reset_item::type_id::create("reset_assert", this);
        tr.asserted = 1'b1;
        tr.kind = uart_reset_kind_e'({!new_presetn, !new_uart_rst_n});
        tr.observed_time = $time;
        ap.write(tr);
      end

      if ((!old_presetn && new_presetn) ||
          (!old_uart_rst_n && new_uart_rst_n)) begin
        tr = uart_reset_item::type_id::create("reset_release", this);
        tr.asserted = 1'b0;
        tr.kind = uart_reset_kind_e'({!old_presetn, !old_uart_rst_n});
        tr.observed_time = $time;
        ap.write(tr);
      end

      old_presetn = new_presetn;
      old_uart_rst_n = new_uart_rst_n;
    end
  endtask
endclass

class uart_reg_reset_sync extends uvm_component;
  `uvm_component_utils(uart_reg_reset_sync)

  uvm_analysis_imp_reset_ral #(uart_reset_item, uart_reg_reset_sync) reset_export;
  uart_reg_block regmodel;
  int unsigned reset_count;

  function new(string name = "uart_reg_reset_sync", uvm_component parent = null);
    super.new(name, parent);
    reset_export = new("reset_export", this);
  endfunction

  function void write_reset_ral(uart_reset_item tr);
    if (tr.asserted && tr.kind[1]) begin
      regmodel.reset();
      reset_count++;
    end
  endfunction
endclass
