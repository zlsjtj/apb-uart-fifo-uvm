package regblock_pkg;
  import uvm_pkg::*;
  import apb_agent_pkg::*;
  `include "uvm_macros.svh"

  // Oracle consumes monitor transactions, never driver response fields.
  class regblock_checker extends uvm_subscriber #(apb_item);
    `uvm_component_utils(regblock_checker)
    bit [31:0] scratch = 32'h12345678;
    bit [31:0] control = 0;
    int unsigned observed = 0;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(apb_item t);
      bit expected_error;
      bit [31:0] expected_data;
      observed++;
      expected_error = !(t.addr inside {8'h00, 8'h04, 8'h08}) ||
                       (t.kind == apb_item::APB_WRITE && t.addr == 0);
      if (t.slverr !== expected_error)
        `uvm_error("REGBLOCK_ERROR", $sformatf("addr=%02h expected PSLVERR=%b got=%b", t.addr, expected_error, t.slverr))
      if (t.kind == apb_item::APB_READ) begin
        expected_data = 0;
        case (t.addr)
          8'h00: expected_data = 32'h52454731;
          8'h04: expected_data = scratch;
          8'h08: expected_data = control;
          default: expected_data = 0;
        endcase
        if (t.rdata !== expected_data)
          `uvm_error("REGBLOCK_DATA", $sformatf("addr=%02h expected=%08h got=%08h", t.addr, expected_data, t.rdata))
      end
      if (t.kind == apb_item::APB_WRITE && !expected_error) begin
        case (t.addr)
          8'h04: scratch = t.data;
          8'h08: control = t.data & 32'h3;
          default: ;
        endcase
      end
    endfunction
    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (observed != 12)
        `uvm_error("REGBLOCK_COUNT", $sformatf("expected 12 monitored transfers, got %0d", observed))
      `uvm_info("REGBLOCK_SUMMARY", $sformatf("observed=%0d expected=12", observed), UVM_NONE)
    endfunction
  endclass

  class regblock_env extends uvm_env;
    `uvm_component_utils(regblock_env)
    apb_agent agent;
    regblock_checker sb;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = apb_agent::type_id::create("agent", this);
      sb = regblock_checker::type_id::create("sb", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.ap.connect(sb.analysis_export);
    endfunction
  endclass

  class regblock_sequence extends uvm_sequence #(apb_item);
    `uvm_object_utils(regblock_sequence)
    function new(string name="regblock_sequence"); super.new(name); endfunction
    task transfer(bit wr, bit [7:0] addr, bit [31:0] data=0);
      apb_item tr = apb_item::type_id::create("tr");
      start_item(tr);
      tr.kind = wr ? apb_item::APB_WRITE : apb_item::APB_READ;
      tr.addr = addr;
      tr.data = data;
      tr.idle_cycles = 0;
      finish_item(tr);
    endtask
    task body();
      transfer(0, 8'h00); // ID and both reset defaults
      transfer(0, 8'h04);
      transfer(0, 8'h08);
      transfer(1, 8'h04, 32'ha5a55a5a);
      transfer(0, 8'h04);
      transfer(1, 8'h08, 32'hffffffff);
      transfer(0, 8'h08); // reserved bits read zero
      transfer(1, 8'h00, 0); // read-only error, ID unchanged
      transfer(0, 8'h00);
      transfer(0, 8'h0c); // unmapped read error
      transfer(1, 8'h0c, 32'hdeadbeef); // unmapped write error
      transfer(0, 8'h04); // no collateral register corruption
    endtask
  endclass

  class regblock_test extends uvm_test;
    `uvm_component_utils(regblock_test)
    regblock_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = regblock_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
      regblock_sequence seq = regblock_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage
