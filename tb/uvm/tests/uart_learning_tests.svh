// Registered for individual runs; deliberately absent from RegressionTests.
class uart_learning_baud_test extends uart_base_test;
  `uvm_component_utils(uart_learning_baud_test)
  function new(string name = "uart_learning_baud_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    uart_learning_baud_seq seq;
    phase.raise_objection(this);
    seq = uart_learning_baud_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass
