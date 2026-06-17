class uart_scoreboard extends uvm_component;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp_apb_sb  #(apb_item,  uart_scoreboard) apb_export;
  uvm_analysis_imp_tx_sb   #(uart_item, uart_scoreboard) tx_export;
  uvm_analysis_imp_rx_sb   #(uart_item, uart_scoreboard) rx_export;

  bit [7:0] exp_tx_q[$];
  bit [7:0] exp_rx_q[$];
  bit       loopback_en;
  int       tx_checked;
  int       rx_checked;

  localparam bit [7:0] ADDR_CTRL   = 8'h00;
  localparam bit [7:0] ADDR_TXDATA = 8'h0c;
  localparam bit [7:0] ADDR_RXDATA = 8'h10;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    apb_export = new("apb_export", this);
    tx_export  = new("tx_export", this);
    rx_export  = new("rx_export", this);
  endfunction

  function void write_apb_sb(apb_item tr);
    if (tr.addr == ADDR_CTRL && tr.kind == apb_item::APB_WRITE && !tr.slverr) begin
      loopback_en = tr.data[1];
    end

    if (tr.addr == ADDR_TXDATA && tr.kind == apb_item::APB_WRITE && !tr.slverr) begin
      exp_tx_q.push_back(tr.data[7:0]);
    end

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
        if (loopback_en) begin
          exp_rx_q.push_back(tr.data);
        end
      end
    end
  endfunction

  function void write_rx_sb(uart_item tr);
    if (!loopback_en) begin
      exp_rx_q.push_back(tr.data);
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (exp_tx_q.size() != 0) begin
      `uvm_error("SB_TX_LEFT", $sformatf("%0d TX byte(s) were not observed", exp_tx_q.size()))
    end

    if (exp_rx_q.size() != 0) begin
      `uvm_warning("SB_RX_LEFT", $sformatf("%0d RX byte(s) were not read back", exp_rx_q.size()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB_SUMMARY",
              $sformatf("checked TX=%0d RX=%0d", tx_checked, rx_checked),
              UVM_LOW)
  endfunction
endclass
