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

