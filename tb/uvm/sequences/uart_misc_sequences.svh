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

    for (int i = 0; i < 2*fifo_depth()+8; i++) begin
      apb_write_status(ADDR_TXDATA, i[7:0], 0, slverr);
      if (slverr) begin
        saw_full_err = 1'b1;
      end
    end

    if (!saw_full_err) begin
      `uvm_error("FIFO_FULL", "TX FIFO overflow path was not exercised")
    end

    apb_read(ADDR_STATUS, data, 2);
    wait_tx_idle();
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
  bit [31:0] baud_value = 32'd1;
  bit configure_first = 1'b1;
  int unsigned first_read_idle = 180;
  int unsigned next_read_idle = 70;

  function new(string name = "uart_rx_read_seq");
    super.new(name);
    pattern = '{8'h24, 8'h81, 8'h7e, 8'hc3, 8'h5a};
  endfunction

  task body();
    bit [31:0] data;

    if (configure_first) begin
      apb_write(ADDR_BAUD, baud_value, 1);
      apb_write(ADDR_CTRL, 32'h1, 4);
    end

    foreach (pattern[i]) begin
      apb_read(ADDR_RXDATA, data, (i == 0) ? first_read_idle : next_read_idle);
      if (data[7:0] != pattern[i]) begin
        `uvm_error("EXT_RX", $sformatf("read 0x%02h expected 0x%02h", data[7:0], pattern[i]))
      end
    end
  endtask
endclass

class uart_external_rx_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_external_rx_seq)

  bit [7:0] pattern[$];
  int unsigned bit_cycles = 1;
  int unsigned edge_offset_ps = 1000;

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
      tr.bit_cycles = bit_cycles;
      tr.edge_offset_ps = edge_offset_ps;
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
