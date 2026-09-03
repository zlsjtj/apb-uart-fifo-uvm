class uart_base_apb_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(uart_base_apb_seq)

  // Short aliases keep the existing sequences readable while all numeric
  // definitions remain in apb_uart_reg_pkg.
  localparam bit [7:0] ADDR_CTRL   = UART_ADDR_CTRL;
  localparam bit [7:0] ADDR_STATUS = UART_ADDR_STATUS;
  localparam bit [7:0] ADDR_BAUD   = UART_ADDR_BAUD;
  localparam bit [7:0] ADDR_TXDATA = UART_ADDR_TXDATA;
  localparam bit [7:0] ADDR_RXDATA = UART_ADDR_RXDATA;

  function new(string name = "uart_base_apb_seq");
    super.new(name);
  endfunction

  task automatic apb_write(input bit [7:0] addr,
                           input bit [31:0] data,
                           input int unsigned idle_cycles = 0);
    bit slverr;
    apb_write_status(addr, data, idle_cycles, slverr);
  endtask

  task automatic apb_write_status(input  bit [7:0] addr,
                                  input  bit [31:0] data,
                                  input  int unsigned idle_cycles,
                                  output bit slverr);
    apb_item tr;
    tr = apb_item::type_id::create("wr_tr");
    start_item(tr);
    tr.kind        = apb_item::APB_WRITE;
    tr.addr        = addr;
    tr.data        = data;
    tr.idle_cycles = idle_cycles;
    finish_item(tr);
    slverr = tr.slverr;
  endtask

  task automatic apb_read(input  bit [7:0] addr,
                          output bit [31:0] data,
                          input  int unsigned idle_cycles = 0);
    bit slverr;
    apb_read_status(addr, data, idle_cycles, slverr);
  endtask

  task automatic apb_read_status(input  bit [7:0] addr,
                                 output bit [31:0] data,
                                 input  int unsigned idle_cycles,
                                 output bit slverr);
    apb_item tr;
    tr = apb_item::type_id::create("rd_tr");
    start_item(tr);
    tr.kind        = apb_item::APB_READ;
    tr.addr        = addr;
    tr.data        = '0;
    tr.idle_cycles = idle_cycles;
    finish_item(tr);
    data   = tr.rdata;
    slverr = tr.slverr;
  endtask

  task automatic expect_error(bit got_err, string msg);
    if (!got_err) begin
      `uvm_error("SEQ_EXP_ERR", msg)
    end
  endtask
endclass

class uart_ral_predict_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_ral_predict_seq)

  function new(string name = "uart_ral_predict_seq");
    super.new(name);
  endfunction

  task body();
    apb_write(ADDR_CTRL, 32'h6, 1);
    apb_write(ADDR_BAUD, 32'd4, 1);
  endtask
endclass

class uart_config_write_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_config_write_seq)

  bit [7:0]  cfg_addr;
  bit [31:0] cfg_data;

  function new(string name = "uart_config_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_write(cfg_addr, cfg_data, 0);
  endtask
endclass

class uart_reg_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_reg_seq)

  function new(string name = "uart_reg_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;
    bit        slverr;

    apb_read(ADDR_CTRL, data, 4);
    if (data[2:0] != 3'b000) begin
      `uvm_error("REG_DEFAULT", $sformatf("CTRL reset value is 0x%0h", data))
    end

    apb_read(ADDR_BAUD, data, 1);
    if (data != 32'd16) begin
      `uvm_error("REG_DEFAULT", $sformatf("BAUD reset value is %0d", data))
    end

    apb_write(ADDR_CTRL, 32'h5, 2);
    apb_read(ADDR_CTRL, data, 1);
    if (data[2:0] != 3'b101) begin
      `uvm_error("REG_RW", $sformatf("CTRL readback mismatch 0x%0h", data))
    end

    apb_write(ADDR_BAUD, 32'd4, 1);
    apb_read(ADDR_BAUD, data, 1);
    if (data != 32'd4) begin
      `uvm_error("REG_RW", $sformatf("BAUD readback mismatch 0x%0h", data))
    end

    apb_read_status(8'h80, data, 1, slverr);
    expect_error(slverr, "invalid address did not report pslverr");

    apb_write_status(ADDR_STATUS, 32'h1, 1, slverr);
    expect_error(slverr, "STATUS write did not report pslverr");
  endtask
endclass

