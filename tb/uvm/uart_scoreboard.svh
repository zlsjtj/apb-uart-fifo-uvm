class uart_scoreboard extends uvm_component;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp_apb_sb  #(apb_item,  uart_scoreboard) apb_export;
  uvm_analysis_imp_tx_sb   #(uart_item, uart_scoreboard) tx_export;
  uvm_analysis_imp_exp_tx_sb #(uart_item, uart_scoreboard) exp_tx_export;
  uvm_analysis_imp_exp_rx_sb #(uart_item, uart_scoreboard) exp_rx_export;
  uvm_analysis_imp_reset_sb #(uart_reset_item, uart_scoreboard) reset_export;

  bit [7:0] exp_tx_q[$];
  bit [7:0] exp_rx_q[$];
  int       tx_checked;
  int       rx_checked;
  int       reset_flushes;

  localparam bit [7:0] ADDR_RXDATA = UART_ADDR_RXDATA;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    apb_export = new("apb_export", this);
    tx_export  = new("tx_export", this);
    exp_tx_export = new("exp_tx_export", this);
    exp_rx_export = new("exp_rx_export", this);
    reset_export = new("reset_export", this);
  endfunction

  function void write_reset_sb(uart_reset_item tr);
    if (tr.asserted) begin
      exp_tx_q.delete();
      exp_rx_q.delete();
      reset_flushes++;
    end
  endfunction

  function void write_apb_sb(apb_item tr);
    if (tr.addr == ADDR_RXDATA && tr.kind == apb_item::APB_READ && !tr.slverr) begin
      if (exp_rx_q.size() == 0) begin
        `uvm_error("SB_RX_EMPTY", $sformatf("unexpected RX read data=0x%02h", tr.rdata[7:0]))
      end else begin
        bit [7:0] exp;
        exp = exp_rx_q.pop_front();
        if (tr.rdata[7:0] !== exp) begin
          `uvm_error("SB_RX_MISMATCH",
                     $sformatf("RX data mismatch exp=0x%02h act=0x%02h", exp, tr.rdata[7:0]))
        end else begin
          rx_checked++;
        end
      end
    end
  endfunction

  function void write_tx_sb(uart_item tr);
    if (tr.frame_err) begin
      `uvm_error("SB_TX_FRAME", $sformatf("TX frame error on data=0x%02h", tr.data))
    end

    if (exp_tx_q.size() == 0) begin
      `uvm_error("SB_TX_EMPTY", $sformatf("unexpected TX frame data=0x%02h", tr.data))
    end else begin
      bit [7:0] exp;
      exp = exp_tx_q.pop_front();
      if (tr.data !== exp) begin
        `uvm_error("SB_TX_MISMATCH",
                   $sformatf("TX data mismatch exp=0x%02h act=0x%02h", exp, tr.data))
      end else begin
        tx_checked++;
      end
    end
  endfunction

  function void write_exp_tx_sb(uart_item tr);
    exp_tx_q.push_back(tr.data);
  endfunction

  function void write_exp_rx_sb(uart_item tr);
    exp_rx_q.push_back(tr.data);
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (exp_tx_q.size() != 0) begin
      `uvm_error("SB_TX_LEFT", $sformatf("%0d TX byte(s) were not observed", exp_tx_q.size()))
    end

    if (exp_rx_q.size() != 0) begin
      `uvm_error("SB_RX_LEFT", $sformatf("%0d RX byte(s) were not read back", exp_rx_q.size()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB_SUMMARY",
              $sformatf("checked TX=%0d RX=%0d reset_flushes=%0d",
                        tx_checked, rx_checked, reset_flushes),
              UVM_LOW)
  endfunction
endclass
