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
    // Allow the independently timed peer to start only after the APB-to-UART
    // configuration mailbox and baud generator have settled.
    tr.gap_cycles = 10;
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
