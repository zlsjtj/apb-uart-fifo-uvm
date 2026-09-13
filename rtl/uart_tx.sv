module uart_tx (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       enable,
  input  logic       bit_tick_i,
  input  logic [7:0] data_i,
  input  logic       valid_i,
  output logic       ready_o,
  output logic       tx_o,
  output logic       retired_o
);

  typedef enum logic [1:0] {
    TX_IDLE,
    TX_SHIFT
  } tx_state_e;

  tx_state_e state;
  logic [8:0] shifter;
  logic [3:0] bit_cnt;
  logic stop_pending;

  assign ready_o = (state == TX_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= TX_IDLE;
      shifter <= 10'h3ff;
      bit_cnt <= '0;
      tx_o    <= 1'b1;
      stop_pending <= 1'b0;
      retired_o <= 1'b0;
    end else if (!enable) begin
      state   <= TX_IDLE;
      shifter <= 10'h3ff;
      bit_cnt <= '0;
      tx_o    <= 1'b1;
      // Disabling is an explicit abort, not successful frame delivery. Retire
      // an already popped byte so TX_BUSY cannot remain stuck after abort.
      retired_o <= (state == TX_SHIFT) || stop_pending;
      stop_pending <= 1'b0;
    end else begin
      retired_o <= 1'b0;
      unique case (state)
        TX_IDLE: begin
          tx_o <= 1'b1;
          if (stop_pending && bit_tick_i) begin
            retired_o <= 1'b1;
            stop_pending <= 1'b0;
          end
          if (valid_i && bit_tick_i) begin
            tx_o    <= 1'b0;
            shifter <= {1'b1, data_i};
            bit_cnt <= 4'd0;
            state   <= TX_SHIFT;
          end
        end

        TX_SHIFT: begin
          if (bit_tick_i) begin
            tx_o    <= shifter[0];
            shifter <= {1'b1, shifter[8:1]};
            bit_cnt <= bit_cnt + 4'd1;
            if (bit_cnt == 4'd8) begin
              state <= TX_IDLE;
`ifdef UART_MUTATE_TX_EARLY_COMPLETE
              retired_o <= 1'b1;
              stop_pending <= 1'b0;
`else
              stop_pending <= 1'b1;
`endif
            end
          end
        end

        default: state <= TX_IDLE;
      endcase
    end
  end

endmodule
