module apb_uart_cfg_cdc (
  input  logic        pclk,
  input  logic        pclk_rst_n,
  input  logic        uart_clk,
  input  logic        uart_rst_n,
  input  logic        cfg_write,
  input  logic [2:0]  cfg_ctrl_value,
  input  logic [31:0] cfg_baud_value,
  input  logic [2:0]  apb_ctrl_current,
  input  logic [31:0] apb_baud_current,
  output logic [2:0]  cfg_ctrl_hold,
  output logic [31:0] cfg_baud_hold,
  output logic        cfg_req_tgl,
  output logic        cfg_ack_tgl,
  output logic        cfg_ack_pclk_q1,
  output logic        cfg_ack_pclk_q2,
  output logic        cfg_req_uart_q1,
  output logic        cfg_req_uart_q2,
  output logic        cfg_req_seen,
  output logic        cfg_uart_initialized,
  output logic        cfg_apply_uart,
  output logic        cfg_pending,
  output logic        cfg_busy,
  output logic [2:0]  ctrl_uart_cfg,
  output logic [31:0] baud_uart_cfg
);
  import apb_uart_reg_pkg::*;

  (* ASYNC_REG = "TRUE" *) logic cfg_ack_meta, cfg_ack_sync;
  (* ASYNC_REG = "TRUE" *) logic cfg_req_meta, cfg_req_sync;

  logic cfg_inflight;
  assign cfg_inflight = (cfg_req_tgl != cfg_ack_pclk_q2);
  assign cfg_busy = cfg_inflight || cfg_pending;
  assign cfg_ack_pclk_q1 = cfg_ack_meta;
  assign cfg_ack_pclk_q2 = cfg_ack_sync;
  assign cfg_req_uart_q1 = cfg_req_meta;
  assign cfg_req_uart_q2 = cfg_req_sync;

  always_ff @(posedge pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) begin
      cfg_ctrl_hold <= UART_CTRL_RESET[2:0];
      cfg_baud_hold <= UART_BAUD_RESET;
      cfg_req_tgl <= 1'b0;
      cfg_ack_meta <= 1'b0;
      cfg_ack_sync <= 1'b0;
      // Replay surviving APB registers after either domain resets. Startup
      // uses exactly the same stable-payload handshake as a normal write.
      cfg_pending <= 1'b1;
    end else begin
      cfg_ack_meta <= cfg_ack_tgl;
      cfg_ack_sync <= cfg_ack_meta;
      if (cfg_write) begin
        if (!cfg_inflight) begin
          cfg_ctrl_hold <= cfg_ctrl_value;
          cfg_baud_hold <= cfg_baud_value;
          cfg_req_tgl <= ~cfg_req_tgl;
          cfg_pending <= 1'b0;
        end else begin
          cfg_pending <= 1'b1;
        end
      end else if (!cfg_inflight && cfg_pending) begin
        cfg_ctrl_hold <= apb_ctrl_current;
        cfg_baud_hold <= apb_baud_current;
        cfg_req_tgl <= ~cfg_req_tgl;
        cfg_pending <= 1'b0;
      end
    end
  end

  always_ff @(posedge uart_clk or negedge uart_rst_n) begin
    if (!uart_rst_n) begin
      cfg_req_meta <= 1'b0;
      cfg_req_sync <= 1'b0;
      cfg_req_seen <= 1'b0;
      cfg_uart_initialized <= 1'b0;
      cfg_apply_uart <= 1'b0;
      cfg_ack_tgl <= 1'b0;
      ctrl_uart_cfg <= UART_CTRL_RESET[2:0];
      baud_uart_cfg <= UART_BAUD_RESET;
    end else begin
      cfg_req_meta <= cfg_req_tgl;
      cfg_req_sync <= cfg_req_meta;
      cfg_apply_uart <= 1'b0;
      if (cfg_req_sync != cfg_req_seen) begin
        cfg_uart_initialized <= 1'b1;
        ctrl_uart_cfg <= cfg_ctrl_hold;
        baud_uart_cfg <= cfg_baud_hold;
        cfg_req_seen <= cfg_req_sync;
`ifdef UART_MUTATE_CFG_ACK_STUCK
        cfg_ack_tgl <= 1'b0;
`else
        cfg_ack_tgl <= cfg_req_sync;
`endif
`ifndef UART_MUTATE_CFG_APPLY_DROP
        cfg_apply_uart <= 1'b1;
`endif
      end
    end
  end
endmodule
