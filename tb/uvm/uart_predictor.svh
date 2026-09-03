class uart_predictor extends uvm_component;
  `uvm_component_utils(uart_predictor)

  uvm_analysis_imp_apb_pred #(apb_item, uart_predictor) apb_export;
  uvm_analysis_imp_tx_pred #(uart_item, uart_predictor) tx_export;
  uvm_analysis_imp_rx_line_pred #(uart_item, uart_predictor) rx_line_export;
  uvm_analysis_imp_reset_pred #(uart_reset_item, uart_predictor) reset_export;
  uvm_analysis_port #(uart_item) exp_tx_ap;
  uvm_analysis_port #(uart_item) exp_rx_ap;
  uart_env_cfg cfg;
  uart_serial_cfg serial_cfg;

  bit loopback_effective;
  int unsigned predicted_rx_occupancy;
  int unsigned bad_rx_rejected;
  int unsigned full_rx_dropped;
  int unsigned cfg_updates;

  function new(string name = "uart_predictor", uvm_component parent = null);
    super.new(name, parent);
    apb_export = new("apb_export", this);
    tx_export = new("tx_export", this);
    rx_line_export = new("rx_line_export", this);
    reset_export = new("reset_export", this);
    exp_tx_ap = new("exp_tx_ap", this);
    exp_rx_ap = new("exp_rx_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal("NOCFG", "uart_env_cfg is not set")
    end
    if (!uvm_config_db#(uart_serial_cfg)::get(this, "", "serial_cfg", serial_cfg)) begin
      `uvm_fatal("NOSERIALCFG", "uart_serial_cfg is not set")
    end
  endfunction

  function void write_apb_pred(apb_item tr);
    uart_item exp;

    if (tr.slverr) begin
      return;
    end

    if (tr.kind == apb_item::APB_WRITE) begin
      if (tr.addr == UART_ADDR_CTRL) begin
        serial_cfg.ctrl = tr.data[2:0] & UART_CTRL_MASK[2:0];
        loopback_effective = serial_cfg.ctrl[UART_CTRL_LOOPBACK_BIT];
        serial_cfg.apb_updates++;
        cfg_updates++;
      end else if (tr.addr == UART_ADDR_BAUD) begin
        serial_cfg.baud = (tr.data == 0) ? UART_BAUD_MIN : tr.data;
        serial_cfg.apb_updates++;
        cfg_updates++;
      end
    end

    if ((tr.kind == apb_item::APB_WRITE) && (tr.addr == UART_ADDR_TXDATA)) begin
      exp = uart_item::type_id::create("expected_tx");
      exp.data = tr.data[7:0];
      exp.frame_err = 1'b0;
      exp_tx_ap.write(exp);
    end

    if ((tr.kind == apb_item::APB_READ) && (tr.addr == UART_ADDR_RXDATA) &&
        (predicted_rx_occupancy != 0)) begin
      predicted_rx_occupancy--;
    end
  endfunction

  function void write_tx_pred(uart_item tr);
    if (loopback_effective && !tr.frame_err) begin
      predict_rx(tr, "loopback");
    end
  endfunction

  function void write_rx_line_pred(uart_item tr);
    if (loopback_effective) begin
      return;
    end
    if (tr.frame_err) begin
      bad_rx_rejected++;
      return;
    end
    predict_rx(tr, "external RX pin");
  endfunction

  function void write_reset_pred(uart_reset_item tr);
    if (!tr.asserted) begin
      return;
    end
    predicted_rx_occupancy = 0;
    if (tr.kind[1]) begin
      serial_cfg.reset_to_defaults();
      loopback_effective = 1'b0;
    end else begin
      loopback_effective = serial_cfg.ctrl[UART_CTRL_LOOPBACK_BIT];
    end
  endfunction

  function void predict_rx(uart_item observed, string source);
    uart_item exp;
    if (predicted_rx_occupancy >= cfg.fifo_depth()) begin
      full_rx_dropped++;
      return;
    end
    exp = uart_item::type_id::create("expected_rx");
    exp.copy(observed);
    exp_rx_ap.write(exp);
    predicted_rx_occupancy++;
    `uvm_info("UART_PRED", $sformatf("predicted RX from %s: 0x%02h", source, exp.data), UVM_HIGH)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("PRED_SUMMARY",
              $sformatf("cfg_updates=%0d rejected_bad_RX=%0d dropped_full_RX=%0d occupancy=%0d",
                        cfg_updates, bad_rx_rejected, full_rx_dropped,
                        predicted_rx_occupancy), UVM_LOW)
  endfunction
endclass
