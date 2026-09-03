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

