class uart_base_vseq extends uvm_sequence;
  `uvm_object_utils(uart_base_vseq)
  `uvm_declare_p_sequencer(uart_virtual_sequencer)

  function new(string name = "uart_base_vseq");
    super.new(name);
  endfunction
endclass

class uart_external_rx_vseq extends uart_base_vseq;
  `uvm_object_utils(uart_external_rx_vseq)

  function new(string name = "uart_external_rx_vseq");
    super.new(name);
  endfunction

  task body();
    uart_rx_read_seq     apb_seq;
    uart_external_rx_seq rx_seq;

    apb_seq = uart_rx_read_seq::type_id::create("apb_seq");
    rx_seq  = uart_external_rx_seq::type_id::create("rx_seq");
    fork
      apb_seq.start(p_sequencer.apb_seqr);
      rx_seq.start(p_sequencer.uart_seqr);
    join
  endtask
endclass
