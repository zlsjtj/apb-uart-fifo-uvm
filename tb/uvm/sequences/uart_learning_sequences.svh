// Optional teaching test: public APB observations, no internal probes.
class uart_learning_baud_seq extends uart_base_apb_seq;
  `uvm_object_utils(uart_learning_baud_seq)
  function new(string name = "uart_learning_baud_seq"); super.new(name); endfunction

  task automatic check_baud(input bit [31:0] requested,
                            input bit [31:0] expected);
    bit [31:0] actual;
    bit err;
    wait_tx_idle();
    apb_write_status(UART_ADDR_BAUD, requested, 1, err);
    if (err) `uvm_error("LEARN_BAUD_WRITE", "Legal BAUD write returned PSLVERR")
    wait_config_ready();
    apb_read_status(UART_ADDR_BAUD, actual, 1, err);
    if (err || actual != expected)
      `uvm_error("LEARN_BAUD_READ", $sformatf(
        "requested=%0d expected=%0d actual=%0d PSLVERR=%0b",
        requested, expected, actual, err))
  endtask

  task body();
    // Explicit expectations: do not derive the oracle from DUT readback.
    check_baud(0, 1);
    check_baud(1, 1);
    check_baud(7, 7);
    check_baud(16, 16);
  endtask
endclass
