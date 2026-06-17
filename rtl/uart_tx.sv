module uart_tx (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       enable,
  input  logic [7:0] data_i,
  input  logic       valid_i,
  output logic       ready_o,
  output logic       tx_o
);

  typedef enum logic [1:0] {
    TX_IDLE,
    TX_SHIFT
  } tx_state_e;

  tx_state_e state;
  logic [9:0] shifter;
  logic [3:0] bit_cnt;

  assign ready_o = (state == TX_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= TX_IDLE;
      shifter <= 10'h3ff;
      bit_cnt <= '0;
      tx_o    <= 1'b1;
    end else if (!enable) begin
      state   <= TX_IDLE;
      shifter <= 10'h3ff;
      bit_cnt <= '0;
      tx_o    <= 1'b1;
    end else begin
      unique case (state)
        TX_IDLE: begin
          tx_o <= 1'b1;
          if (valid_i) begin
            shifter <= {1'b1, data_i, 1'b0};
            bit_cnt <= 4'd0;
            state   <= TX_SHIFT;
          end
        end

        TX_SHIFT: begin
          tx_o    <= shifter[0];
          shifter <= {1'b1, shifter[9:1]};
          bit_cnt <= bit_cnt + 4'd1;
          if (bit_cnt == 4'd9) begin
            state <= TX_IDLE;
          end
        end

        default: state <= TX_IDLE;
      endcase
    end
  end

endmodule
