class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;

  function new(string name = "uart_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "env.apb",  "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "env.uart", "is_active", UVM_ACTIVE);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction
endclass

class uart_reg_test extends uart_base_test;
  `uvm_component_utils(uart_reg_test)

  function new(string name = "uart_reg_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_reg_seq seq;
    phase.raise_objection(this);
    seq = uart_reg_seq::type_id::create("seq");
    seq.start(env.apb.seqr);
    #1us;
    phase.drop_objection(this);
  endtask
endclass

class uart_config_latency_test extends uart_base_test;
  `uvm_component_utils(uart_config_latency_test)

  virtual uart_probe_if probe_vif;

  function new(string name = "uart_config_latency_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_probe_if)::get(this, "", "probe_vif", probe_vif)) begin
      `uvm_fatal("NOPROBEVIF", "probe_vif is not set")
    end
  endfunction

  task automatic write_and_check_apply(input bit [7:0] addr,
                                       input bit [31:0] data,
                                       input string register_name);
    uart_config_write_seq seq;
    time apb_done_time;
    time effective_time;
    bit  applied;

    wait (probe_vif.cfg_apply_uart == 1'b0);
    seq = uart_config_write_seq::type_id::create($sformatf("%s_write", register_name));
    seq.cfg_addr = addr;
    seq.cfg_data = data;
    seq.start(env.apb.seqr);
    apb_done_time = $time;

    if (((addr == UART_ADDR_CTRL) && (probe_vif.ctrl_uart_cfg == data[2:0])) ||
        ((addr == UART_ADDR_BAUD) && (probe_vif.baud_uart_cfg == data))) begin
      `uvm_error("CFG_LATENCY", $sformatf("%s became effective before APB completion was recorded",
                                           register_name))
    end

    fork
      begin
        if (addr == UART_ADDR_CTRL) begin
          wait ((probe_vif.cfg_apply_uart == 1'b1) &&
                (probe_vif.ctrl_uart_cfg == data[2:0]));
        end else begin
          wait ((probe_vif.cfg_apply_uart == 1'b1) &&
                (probe_vif.baud_uart_cfg == data));
        end
        effective_time = $time;
        applied = 1'b1;
      end
      begin
        #2us;
      end
    join_any
    disable fork;

    if (!applied) begin
      `uvm_error("CFG_LATENCY", $sformatf("%s did not become effective in the UART domain",
                                           register_name))
      return;
    end

    if ((effective_time <= apb_done_time) ||
        ((addr == UART_ADDR_CTRL) && (probe_vif.ctrl_uart_cfg != data[2:0])) ||
        ((addr == UART_ADDR_BAUD) && (probe_vif.baud_uart_cfg != data))) begin
      `uvm_error("CFG_LATENCY",
                 $sformatf("%s APB_done=%0t UART_apply=%0t ctrl=0x%0h baud=%0d",
                           register_name, apb_done_time, effective_time,
                           probe_vif.ctrl_uart_cfg, probe_vif.baud_uart_cfg))
    end else begin
      `uvm_info("CFG_LATENCY",
                $sformatf("%s APB_done=%0t UART_apply=%0t latency=%0t",
                          register_name, apb_done_time, effective_time,
                          effective_time - apb_done_time), UVM_LOW)
    end

    wait (probe_vif.cfg_apply_uart == 1'b0);
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait (probe_vif.uart_clk_rst_n && probe_vif.cfg_apply_uart == 1'b0);
    write_and_check_apply(UART_ADDR_BAUD, 32'd7, "BAUD");
    write_and_check_apply(UART_ADDR_CTRL, 32'h5, "CTRL");
    #500ns;
    phase.drop_objection(this);
  endtask
endclass

class uart_config_stress_test extends uart_base_test;
  `uvm_component_utils(uart_config_stress_test)

  virtual uart_probe_if probe_vif;
  virtual reset_if      reset_vif;

  function new(string name = "uart_config_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_probe_if)::get(this, "", "probe_vif", probe_vif)) begin
      `uvm_fatal("NOPROBEVIF", "probe_vif is not set")
    end
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction

  task automatic wait_for_config(input bit [2:0] expected_ctrl,
                                 input bit [31:0] expected_baud,
                                 input string check_name);
    bit matched;
    fork
      begin
        wait (probe_vif.uart_clk_rst_n && !probe_vif.cfg_busy &&
              (probe_vif.ctrl_uart_cfg == expected_ctrl) &&
              (probe_vif.baud_uart_cfg == expected_baud));
        matched = 1'b1;
      end
      begin
        #4us;
      end
    join_any
    disable fork;
    if (!matched) begin
      `uvm_error("CFG_STRESS",
                 $sformatf("%s did not converge: busy=%0b pending=%0b ctrl=0x%0h baud=%0d",
                           check_name, probe_vif.cfg_busy, probe_vif.cfg_pending,
                           probe_vif.ctrl_uart_cfg, probe_vif.baud_uart_cfg))
    end
  endtask

  task run_phase(uvm_phase phase);
    uart_config_burst_seq burst;
    uart_config_write_seq write_seq;
    bit saw_busy_write;

    phase.raise_objection(this);
    wait (probe_vif.pclk_rst_n && probe_vif.uart_clk_rst_n &&
          probe_vif.cfg_uart_initialized);

    fork
      begin
        forever begin
          @(posedge probe_vif.pclk);
          if (probe_vif.cfg_write && probe_vif.cfg_busy) begin
            saw_busy_write = 1'b1;
          end
        end
      end
      begin
        burst = uart_config_burst_seq::type_id::create("burst");
        burst.start(env.apb.seqr);
      end
    join_any
    disable fork;

    wait_for_config(3'b011, 32'd9, "back-to-back writes");
    if (!saw_busy_write) begin
      `uvm_error("CFG_STRESS", "the burst did not exercise a write while the mailbox was busy")
    end

    // Reset the APB side while a request is in flight. Both visible registers
    // and the effective UART-domain copy must return to their specified reset
    // values; stale pending data must not be applied afterwards.
    write_seq = uart_config_write_seq::type_id::create("pre_apb_reset_write");
    write_seq.cfg_addr = UART_ADDR_BAUD;
    write_seq.cfg_data = 32'd13;
    write_seq.start(env.apb.seqr);
    wait (probe_vif.cfg_busy || probe_vif.cfg_apply_uart);
    reset_vif.pulse_apb_reset(3);
    wait_for_config(UART_CTRL_RESET[2:0], UART_BAUD_RESET, "APB reset recovery");

    // UART-only reset keeps the APB register file alive. The mailbox startup
    // handshake must restore the retained APB configuration exactly once.
    burst = uart_config_burst_seq::type_id::create("retained_burst");
    burst.final_ctrl = 3'b110;
    burst.final_baud = 32'd11;
    burst.start(env.apb.seqr);
    wait_for_config(3'b110, 32'd11, "pre UART-only reset");
    reset_vif.pulse_uart_reset(3);
    wait_for_config(3'b110, 32'd11, "UART-only reset recovery");

    `uvm_info("CFG_STRESS",
              "busy coalescing and APB/UART reset recovery converged to the final register values",
              UVM_LOW)
    #500ns;
    phase.drop_objection(this);
  endtask
endclass

class uart_ral_test extends uart_base_test;
  `uvm_component_utils(uart_ral_test)

  virtual reset_if reset_vif;

  function new(string name = "uart_ral_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal("NORESETVIF", "reset_if is not set")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    uvm_reg_data_t value;
    uart_ral_predict_seq predict_seq;

    phase.raise_objection(this);
    if (env.regmodel.ctrl.get_rights(env.regmodel.default_map) != "RW" ||
        env.regmodel.status.get_rights(env.regmodel.default_map) != "RO" ||
        env.regmodel.baud.get_rights(env.regmodel.default_map) != "RW" ||
        env.regmodel.txdata.get_rights(env.regmodel.default_map) != "WO" ||
        env.regmodel.rxdata.get_rights(env.regmodel.default_map) != "RO") begin
      `uvm_error("RAL_RIGHTS", "register access policy does not match the APB specification")
    end

    env.regmodel.ctrl.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                             env.regmodel.default_map);
    if (status != UVM_IS_OK) begin
      `uvm_error("RAL_RESET", "CTRL reset mirror read failed")
    end
    env.regmodel.status.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                               env.regmodel.default_map);
    if (status != UVM_IS_OK) begin
      `uvm_error("RAL_RESET", "STATUS reset mirror read failed")
    end
    env.regmodel.baud.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                             env.regmodel.default_map);
    if (status != UVM_IS_OK) begin
      `uvm_error("RAL_RESET", "BAUD reset mirror read failed")
    end

    env.regmodel.ctrl.write(status, 32'h5, UVM_FRONTDOOR,
                            env.regmodel.default_map);
    env.regmodel.ctrl.read(status, value, UVM_FRONTDOOR,
                           env.regmodel.default_map);
    if ((status != UVM_IS_OK) || (value != 32'h5)) begin
      `uvm_error("RAL_RW", $sformatf("CTRL frontdoor mismatch status=%s value=0x%0h",
                                     status.name(), value))
    end

    env.regmodel.baud.write(status, 0, UVM_FRONTDOOR,
                            env.regmodel.default_map);
    #100ns;
    if (env.regmodel.baud.get_mirrored_value() != UART_BAUD_MIN) begin
      `uvm_error("RAL_NORMALIZE", $sformatf("BAUD=0 mirror is %0d, expected 1",
                                            env.regmodel.baud.get_mirrored_value()))
    end

    predict_seq = uart_ral_predict_seq::type_id::create("predict_seq");
    predict_seq.start(env.apb.seqr);
    #100ns;
    if ((env.regmodel.ctrl.get_mirrored_value() != 32'h6) ||
        (env.regmodel.baud.get_mirrored_value() != 32'd4)) begin
      `uvm_error("RAL_PREDICT", "passive APB predictor did not update CTRL/BAUD mirrors")
    end

    reset_vif.pulse_apb_reset(3);
    env.regmodel.ctrl.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                             env.regmodel.default_map);
    env.regmodel.status.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                               env.regmodel.default_map);
    env.regmodel.baud.mirror(status, UVM_CHECK, UVM_FRONTDOOR,
                             env.regmodel.default_map);
    if ((env.regmodel.ctrl.get_mirrored_value() != UART_CTRL_RESET) ||
        (env.regmodel.status.get_mirrored_value() != UART_STATUS_RESET) ||
        (env.regmodel.baud.get_mirrored_value() != UART_BAUD_RESET)) begin
      `uvm_error("RAL_RESET", "RAL mirrors do not match hardware after APB reset")
    end

    `uvm_info("RAL_SUMMARY", "access policy, frontdoor, predictor and reset mirror checks passed", UVM_LOW)
    #1us;
    phase.drop_objection(this);
  endtask
endclass
