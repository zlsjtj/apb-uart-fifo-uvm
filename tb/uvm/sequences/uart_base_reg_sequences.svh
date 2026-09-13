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

  function int unsigned fifo_depth();
    uart_env_cfg cfg;
    if (!uvm_config_db#(uart_env_cfg)::get(m_sequencer, "", "env_cfg", cfg))
      `uvm_fatal("NOCFG", "Sequence cannot obtain FIFO depth")
    return cfg.fifo_depth();
  endfunction

  task automatic wait_tx_idle();
    bit [31:0] status;
    bit err;
    for (int n = 0; n < 100000; n++) begin
      apb_read_status(ADDR_STATUS, status, 1, err);
      if (!err && !status[UART_STATUS_CFG_BUSY_BIT] &&
          !status[UART_STATUS_TX_BUSY_BIT]) return;
    end
    `uvm_fatal("TX_IDLE_TIMEOUT", "TX_BUSY or CFG_BUSY did not clear within bounded polling")
  endtask

  task automatic apb_write(input bit [7:0] addr,
                           input bit [31:0] data,
                           input int unsigned idle_cycles = 0);
    bit slverr;
    if ((addr == ADDR_CTRL) || (addr == ADDR_BAUD)) wait_tx_idle();
    apb_write_status(addr, data, idle_cycles, slverr);
    if (!slverr && ((addr == ADDR_CTRL) || (addr == ADDR_BAUD)))
      wait_config_ready();
  endtask

  task automatic wait_config_ready();
    bit [31:0] status;
    bit err;
    for (int n = 0; n < 256; n++) begin
      apb_read_status(ADDR_STATUS, status, 0, err);
      if (!err && !status[UART_STATUS_CFG_BUSY_BIT]) return;
    end
    `uvm_fatal("CFG_READY_TIMEOUT", "STATUS.CFG_BUSY did not clear within 256 APB polls")
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

class uart_wait_config_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_wait_config_seq)
  function new(string name = "uart_wait_config_seq"); super.new(name); endfunction
  task body(); wait_config_ready(); endtask
endclass

class uart_rx_config_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_rx_config_seq)
  bit [31:0] baud_value = 1;
  function new(string name = "uart_rx_config_seq"); super.new(name); endfunction
  task body();
    apb_write(ADDR_BAUD, baud_value);
    apb_write(ADDR_CTRL, 1);
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
    bit err;
    // Raw write for the latency test: do not hide the CDC interval by polling.
    apb_write_status(cfg_addr, cfg_data, 0, err);
  endtask
endclass

class uart_config_burst_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_config_burst_seq)

  bit [2:0]  final_ctrl = 3'b011;
  bit [31:0] final_baud = 32'd9;

  function new(string name = "uart_config_burst_seq");
    super.new(name);
  endfunction

  task body();
    bit err;
    // Keep the APB writes back-to-back. The first transfer starts the CDC
    // mailbox; later transfers exercise the single-entry pending/coalescing
    // path while the UART clock domain is still acknowledging it.
    apb_write_status(ADDR_BAUD, 32'd4, 0, err);
    apb_write_status(ADDR_CTRL, 32'h5, 0, err);
    apb_write_status(ADDR_BAUD, 32'd7, 0, err);
    apb_write_status(ADDR_CTRL, final_ctrl, 0, err);
    apb_write_status(ADDR_BAUD, final_baud, 0, err);
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
