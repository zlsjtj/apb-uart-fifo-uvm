class uart_base_apb_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(uart_base_apb_seq)

  localparam bit [7:0] ADDR_CTRL   = 8'h00;
  localparam bit [7:0] ADDR_STATUS = 8'h04;
  localparam bit [7:0] ADDR_BAUD   = 8'h08;
  localparam bit [7:0] ADDR_TXDATA = 8'h0c;
  localparam bit [7:0] ADDR_RXDATA = 8'h10;

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

class uart_loopback_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_loopback_seq)

  bit [7:0] pattern[$];

  function new(string name = "uart_loopback_seq");
    super.new(name);
    pattern = '{8'h00, 8'h55, 8'haa, 8'hff, 8'h13, 8'h37};
  endfunction

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h3, 4);

    foreach (pattern[i]) begin
      apb_write(ADDR_TXDATA, pattern[i], i % 3);
    end

    foreach (pattern[i]) begin
      apb_read(ADDR_RXDATA, data, (i == 0) ? 360 : 45);
      if (data[7:0] != pattern[i]) begin
        `uvm_error("LOOPBACK", $sformatf("read 0x%02h expected 0x%02h", data[7:0], pattern[i]))
      end
    end
  endtask
endclass

class uart_baud_loopback_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_baud_loopback_seq)

  bit [7:0] pattern[$];

  function new(string name = "uart_baud_loopback_seq");
    super.new(name);
    pattern = '{8'h3c, 8'ha5, 8'h7e};
  endfunction

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd4, 2);
    apb_write(ADDR_CTRL, 32'h3, 4);

    foreach (pattern[i]) begin
      apb_write(ADDR_TXDATA, pattern[i], i + 1);
    end

    foreach (pattern[i]) begin
      apb_read(ADDR_RXDATA, data, (i == 0) ? 900 : 220);
      if (data[7:0] != pattern[i]) begin
        `uvm_error("BAUD_LOOPBACK", $sformatf("read 0x%02h expected 0x%02h", data[7:0], pattern[i]))
      end
    end
  endtask
endclass

class uart_irq_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_irq_seq)

  function new(string name = "uart_irq_seq");
    super.new(name);
  endfunction

  task automatic check_irq_status(input bit exp_irq,
                                  input bit exp_rx_empty,
                                  input int unsigned idle_cycles,
                                  input string step_name);
    bit [31:0] status;

    apb_read(ADDR_STATUS, status, idle_cycles);
    if (status[4] != exp_irq || status[2] != exp_rx_empty) begin
      `uvm_error("IRQ_STATUS",
                 $sformatf("%s: STATUS=0x%08h, expected irq=%0b rx_empty=%0b",
                           step_name, status, exp_irq, exp_rx_empty))
    end
  endtask

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);

    // Keep loopback enabled while IRQ is disabled. The received byte must stay
    // in the FIFO without asserting the interrupt.
    apb_write(ADDR_CTRL, 32'h3, 4);
    check_irq_status(1'b0, 1'b1, 4, "reset state with IRQ disabled");
    apb_write(ADDR_TXDATA, 32'ha5, 2);
    check_irq_status(1'b0, 1'b0, 360, "RX pending with IRQ disabled");

    // Enabling IRQ while data is already pending must assert it immediately.
    apb_write(ADDR_CTRL, 32'h7, 2);
    check_irq_status(1'b1, 1'b0, 2, "enable IRQ with pending data");
    apb_read(ADDR_RXDATA, data, 2);
    if (data[7:0] != 8'ha5) begin
      `uvm_error("IRQ_DATA", $sformatf("read 0x%02h expected 0xa5", data[7:0]))
    end
    check_irq_status(1'b0, 1'b1, 8, "FIFO empty after first read");

    // With IRQ enabled, a new RX byte must assert it. Disabling IRQ must lower
    // the output without consuming the pending byte.
    apb_write(ADDR_TXDATA, 32'h3c, 2);
    check_irq_status(1'b1, 1'b0, 360, "new RX data with IRQ enabled");
    apb_write(ADDR_CTRL, 32'h3, 2);
    check_irq_status(1'b0, 1'b0, 2, "disable IRQ with pending data");
    apb_write(ADDR_CTRL, 32'h7, 2);
    check_irq_status(1'b1, 1'b0, 2, "re-enable IRQ with pending data");

    apb_read(ADDR_RXDATA, data, 2);
    if (data[7:0] != 8'h3c) begin
      `uvm_error("IRQ_DATA", $sformatf("read 0x%02h expected 0x3c", data[7:0]))
    end
    check_irq_status(1'b0, 1'b1, 8, "FIFO empty after second read");
  endtask
endclass

class uart_frame_error_setup_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_frame_error_setup_seq)

  function new(string name = "uart_frame_error_setup_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h5, 4);
    apb_read(ADDR_STATUS, status, 4);
    if (status[5] != 1'b0 || status[4] != 1'b0 || status[2] != 1'b1) begin
      `uvm_error("FRAME_SETUP",
                 $sformatf("unexpected initial STATUS=0x%08h", status))
    end
  endtask
endclass

class uart_frame_error_check_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_frame_error_check_seq)

  function new(string name = "uart_frame_error_check_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;
    bit [31:0] data;
    bit        slverr;

    apb_read(ADDR_STATUS, status, 4);
    if (status[5] != 1'b1 || status[4] != 1'b0 || status[2] != 1'b1) begin
      `uvm_error("FRAME_REJECT",
                 $sformatf("bad frame STATUS=0x%08h, expected frame_err=1 irq=0 rx_empty=1",
                           status))
    end

    apb_read_status(ADDR_RXDATA, data, 2, slverr);
    expect_error(slverr, "bad frame entered RX FIFO");
  endtask
endclass

class uart_frame_recovery_check_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_frame_recovery_check_seq)

  function new(string name = "uart_frame_recovery_check_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;
    bit [31:0] data;

    apb_read(ADDR_STATUS, status, 4);
    if (status[5] != 1'b0 || status[4] != 1'b1 || status[2] != 1'b0) begin
      `uvm_error("FRAME_RECOVER",
                 $sformatf("recovery STATUS=0x%08h, expected frame_err=0 irq=1 rx_empty=0",
                           status))
    end

    apb_read(ADDR_RXDATA, data, 2);
    if (data[7:0] != 8'h5a) begin
      `uvm_error("FRAME_DATA", $sformatf("read 0x%02h expected 0x5a", data[7:0]))
    end

    apb_read(ADDR_STATUS, status, 8);
    if (status[5] != 1'b0 || status[4] != 1'b0 || status[2] != 1'b1) begin
      `uvm_error("FRAME_RECOVER",
                 $sformatf("final STATUS=0x%08h, expected frame_err=0 irq=0 rx_empty=1",
                           status))
    end
  endtask
endclass

class uart_bad_frame_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_bad_frame_seq)

  function new(string name = "uart_bad_frame_seq");
    super.new(name);
  endfunction

  task body();
    uart_item tr;
    tr = uart_item::type_id::create("bad_frame");
    start_item(tr);
    tr.data       = 8'he1;
    tr.gap_cycles = 3;
    tr.frame_err  = 1'b1;
    finish_item(tr);
  endtask
endclass

class uart_good_recovery_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_good_recovery_seq)

  function new(string name = "uart_good_recovery_seq");
    super.new(name);
  endfunction

  task body();
    uart_item tr;
    tr = uart_item::type_id::create("good_frame");
    start_item(tr);
    tr.data       = 8'h5a;
    tr.gap_cycles = 3;
    tr.frame_err  = 1'b0;
    finish_item(tr);
  endtask
endclass

class uart_rx_fifo_setup_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_rx_fifo_setup_seq)

  function new(string name = "uart_rx_fifo_setup_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h5, 4);
    apb_read(ADDR_STATUS, status, 4);
    if (status[4:2] != 3'b001) begin
      `uvm_error("RX_FIFO_SETUP",
                 $sformatf("initial STATUS=0x%08h, expected irq=0 full=0 empty=1",
                           status))
    end
  endtask
endclass

class uart_rx_fifo_burst_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_rx_fifo_burst_seq)

  function new(string name = "uart_rx_fifo_burst_seq");
    super.new(name);
  endfunction

  task body();
    uart_item tr;

    // FIFO depth is 16. The seventeenth frame checks the full/drop behavior.
    for (int i = 0; i < 17; i++) begin
      tr = uart_item::type_id::create($sformatf("rx_frame_%0d", i));
      start_item(tr);
      tr.data       = 8'h40 + i[7:0];
      tr.gap_cycles = 1;
      tr.frame_err  = 1'b0;
      finish_item(tr);
    end
  endtask
endclass

class uart_rx_fifo_drain_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_rx_fifo_drain_seq)

  function new(string name = "uart_rx_fifo_drain_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;
    bit [31:0] data;

    apb_read(ADDR_STATUS, status, 8);
    if (status[4:2] != 3'b110) begin
      `uvm_error("RX_FIFO_FULL",
                 $sformatf("full STATUS=0x%08h, expected irq=1 full=1 empty=0",
                           status))
    end

    for (int i = 0; i < 16; i++) begin
      apb_read(ADDR_RXDATA, data, 4);
      if (data[7:0] != (8'h40 + i[7:0])) begin
        `uvm_error("RX_FIFO_ORDER",
                   $sformatf("index %0d read 0x%02h expected 0x%02h",
                             i, data[7:0], 8'h40 + i[7:0]))
      end
    end

    apb_read(ADDR_STATUS, status, 20);
    if (status[4:2] != 3'b001) begin
      `uvm_error("RX_FIFO_EMPTY",
                 $sformatf("drained STATUS=0x%08h, expected irq=0 full=0 empty=1",
                           status))
    end
  endtask
endclass

class uart_rx_fifo_recovery_uart_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_rx_fifo_recovery_uart_seq)

  function new(string name = "uart_rx_fifo_recovery_uart_seq");
    super.new(name);
  endfunction

  task body();
    uart_item tr;
    tr = uart_item::type_id::create("recovery_frame");
    start_item(tr);
    tr.data       = 8'ha6;
    tr.gap_cycles = 3;
    tr.frame_err  = 1'b0;
    finish_item(tr);
  endtask
endclass

class uart_rx_fifo_recovery_check_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_rx_fifo_recovery_check_seq)

  function new(string name = "uart_rx_fifo_recovery_check_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status;
    bit [31:0] data;

    apb_read(ADDR_STATUS, status, 8);
    if (status[4:2] != 3'b100) begin
      `uvm_error("RX_FIFO_RECOVER",
                 $sformatf("recovery STATUS=0x%08h, expected irq=1 full=0 empty=0",
                           status))
    end

    apb_read(ADDR_RXDATA, data, 2);
    if (data[7:0] != 8'ha6) begin
      `uvm_error("RX_FIFO_RECOVER",
                 $sformatf("read 0x%02h expected 0xa6", data[7:0]))
    end

    apb_read(ADDR_STATUS, status, 8);
    if (status[4:2] != 3'b001) begin
      `uvm_error("RX_FIFO_RECOVER",
                 $sformatf("final STATUS=0x%08h, expected irq=0 full=0 empty=1",
                           status))
    end
  endtask
endclass

class uart_reset_midflight_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_reset_midflight_seq)

  function new(string name = "uart_reset_midflight_seq");
    super.new(name);
  endfunction

  task body();
    apb_write(ADDR_BAUD, 32'd8, 1);
    apb_write(ADDR_CTRL, 32'h7, 4);
    apb_write(ADDR_TXDATA, 32'ha5, 1);
  endtask
endclass

class uart_reset_defaults_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_reset_defaults_seq)

  function new(string name = "uart_reset_defaults_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    apb_read(ADDR_CTRL, data, 30);
    if (data[2:0] != 3'b000) begin
      `uvm_error("RESET_CTRL", $sformatf("CTRL after reset is 0x%08h", data))
    end

    apb_read(ADDR_BAUD, data, 2);
    if (data != 32'd16) begin
      `uvm_error("RESET_BAUD", $sformatf("BAUD after reset is %0d", data))
    end

    apb_read(ADDR_STATUS, data, 20);
    if (data[5:0] != 6'b000101) begin
      `uvm_error("RESET_STATUS",
                 $sformatf("STATUS after reset is 0x%08h, expected FIFO empty and IRQ low",
                           data))
    end
  endtask
endclass

class uart_reset_preserved_config_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_reset_preserved_config_seq)

  function new(string name = "uart_reset_preserved_config_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    apb_read(ADDR_CTRL, data, 30);
    if (data[2:0] != 3'b111) begin
      `uvm_error("UART_RESET_CTRL",
                 $sformatf("UART-only reset changed CTRL to 0x%08h", data))
    end

    apb_read(ADDR_BAUD, data, 2);
    if (data != 32'd1) begin
      `uvm_error("UART_RESET_BAUD",
                 $sformatf("UART-only reset changed BAUD to %0d", data))
    end

    apb_read(ADDR_STATUS, data, 20);
    if (data[5:0] != 6'b000101) begin
      `uvm_error("UART_RESET_STATUS",
                 $sformatf("STATUS after UART-only reset is 0x%08h", data))
    end
  endtask
endclass

class uart_reset_recovery_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_reset_recovery_seq)

  function new(string name = "uart_reset_recovery_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h7, 4);
    apb_write(ADDR_TXDATA, 32'h5a, 2);
    apb_read(ADDR_RXDATA, data, 500);
    if (data[7:0] != 8'h5a) begin
      `uvm_error("RESET_RECOVER",
                 $sformatf("read 0x%02h expected 0x5a", data[7:0]))
    end

    apb_read(ADDR_STATUS, data, 20);
    if (data[4:2] != 3'b001) begin
      `uvm_error("RESET_RECOVER",
                 $sformatf("recovery STATUS=0x%08h", data))
    end
  endtask
endclass

class uart_baud_tx_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_baud_tx_seq)

  bit [31:0] baud_value;

  function new(string name = "uart_baud_tx_seq");
    super.new(name);
  endfunction

  task body();
    apb_write(ADDR_BAUD, baud_value, 2);
    apb_write(ADDR_CTRL, 32'h1, 4);
    apb_write(ADDR_TXDATA, 32'h55, 2);
  endtask
endclass

class uart_random_apb_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_random_apb_seq)

  rand int unsigned num_bytes;
  bit [7:0] data_q[$];

  constraint c_num {
    num_bytes inside {[8:12]};
  }

  function new(string name = "uart_random_apb_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] rdata;
    bit [7:0]  val;

    if (!randomize()) begin
      `uvm_fatal("RAND", "failed to randomize uart_random_apb_seq")
    end

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h3, 4);

    for (int i = 0; i < num_bytes; i++) begin
      val = $urandom_range(0, 255);
      data_q.push_back(val);
      apb_write(ADDR_TXDATA, val, $urandom_range(0, 4));
      if ((i % 4) == 0) begin
        apb_read(ADDR_STATUS, rdata, 1);
      end
    end

    foreach (data_q[i]) begin
      apb_read(ADDR_RXDATA, rdata, (i == 0) ? 420 : 50);
      if (rdata[7:0] != data_q[i]) begin
        `uvm_error("RAND_RD", $sformatf("read 0x%02h expected 0x%02h", rdata[7:0], data_q[i]))
      end
    end
  endtask
endclass

class uart_fifo_full_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_fifo_full_seq)

  function new(string name = "uart_fifo_full_seq");
    super.new(name);
  endfunction

  task body();
    bit        slverr;
    bit        saw_full_err;
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h1, 4);

    for (int i = 0; i < 24; i++) begin
      apb_write_status(ADDR_TXDATA, i[7:0], 0, slverr);
      if (slverr) begin
        saw_full_err = 1'b1;
      end
    end

    if (!saw_full_err) begin
      `uvm_error("FIFO_FULL", "TX FIFO overflow path was not exercised")
    end

    apb_read(ADDR_STATUS, data, 2);
    apb_read(ADDR_STATUS, data, 850);
  endtask
endclass

class uart_bad_access_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_bad_access_seq)

  function new(string name = "uart_bad_access_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;
    bit [31:0] ctrl_before;
    bit [31:0] baud_before;
    bit        slverr;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h0, 2);

    apb_write_status(ADDR_TXDATA, 32'ha5, 1, slverr);
    expect_error(slverr, "disabled TXDATA write did not report pslverr");

    apb_write(ADDR_CTRL, 32'h1, 2);
    apb_read(ADDR_CTRL, ctrl_before, 1);
    apb_read(ADDR_BAUD, baud_before, 1);

    apb_read_status(ADDR_TXDATA, data, 1, slverr);
    expect_error(slverr, "TXDATA read did not report pslverr");

    apb_read_status(ADDR_RXDATA, data, 1, slverr);
    expect_error(slverr, "empty RXDATA read did not report pslverr");

    apb_write_status(ADDR_RXDATA, 32'h5a, 1, slverr);
    expect_error(slverr, "RXDATA write did not report pslverr");

    apb_write_status(8'h44, 32'h1234, 1, slverr);
    expect_error(slverr, "bad write address did not report pslverr");

    apb_read(ADDR_CTRL, data, 1);
    if (data != ctrl_before) begin
      `uvm_error("BAD_ACCESS_SIDE_EFFECT",
                 $sformatf("CTRL changed after rejected accesses: 0x%08h -> 0x%08h",
                           ctrl_before, data))
    end

    apb_read(ADDR_BAUD, data, 1);
    if (data != baud_before) begin
      `uvm_error("BAD_ACCESS_SIDE_EFFECT",
                 $sformatf("BAUD changed after rejected accesses: 0x%08h -> 0x%08h",
                           baud_before, data))
    end

    apb_read(ADDR_STATUS, data, 1);
    if (data[4:2] != 3'b001) begin
      `uvm_error("BAD_ACCESS_SIDE_EFFECT",
                 $sformatf("unexpected RX/IRQ state after rejected accesses: STATUS=0x%08h", data))
    end
  endtask
endclass

class uart_rx_read_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_rx_read_seq)

  bit [7:0] pattern[$];

  function new(string name = "uart_rx_read_seq");
    super.new(name);
    pattern = '{8'h24, 8'h81, 8'h7e, 8'hc3, 8'h5a};
  endfunction

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h1, 4);

    foreach (pattern[i]) begin
      apb_read(ADDR_RXDATA, data, (i == 0) ? 180 : 70);
      if (data[7:0] != pattern[i]) begin
        `uvm_error("EXT_RX", $sformatf("read 0x%02h expected 0x%02h", data[7:0], pattern[i]))
      end
    end
  endtask
endclass

class uart_external_rx_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_external_rx_seq)

  bit [7:0] pattern[$];

  function new(string name = "uart_external_rx_seq");
    super.new(name);
    pattern = '{8'h24, 8'h81, 8'h7e, 8'hc3, 8'h5a};
  endfunction

  task body();
    uart_item tr;

    foreach (pattern[i]) begin
      tr = uart_item::type_id::create("rx_tr");
      start_item(tr);
      tr.data       = pattern[i];
      tr.gap_cycles = (i == 0) ? 10 : 3;
      finish_item(tr);
    end
  endtask
endclass

class uart_disable_recover_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_disable_recover_seq)

  function new(string name = "uart_disable_recover_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    apb_write(ADDR_BAUD, 32'd1, 1);
    apb_write(ADDR_CTRL, 32'h0, 4);
    apb_write(ADDR_TXDATA, 32'ha5, 2);
    apb_write(ADDR_CTRL, 32'h3, 8);
    apb_write(ADDR_TXDATA, 32'h3c, 2);
    apb_read(ADDR_RXDATA, data, 120);

    if (data[7:0] != 8'h3c) begin
      `uvm_error("RECOVER", $sformatf("read 0x%02h expected 0x3c", data[7:0]))
    end
  endtask
endclass
