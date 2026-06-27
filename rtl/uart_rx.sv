module uart_rx (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       enable,
  input  logic       bit_tick_i,
  input  logic       rx_i,
  output logic [7:0] data_o,
  output logic       valid_o,
  input  logic       ready_i,
  output logic       frame_err_o
);

  typedef enum logic [1:0] {
    RX_IDLE,
    RX_DATA,
    RX_STOP
  } rx_state_e;

  rx_state_e state;
  logic [7:0] shifter;
  logic [2:0] bit_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= RX_IDLE;
      shifter     <= '0;
      bit_cnt     <= '0;
      data_o      <= '0;
      valid_o     <= 1'b0;
      frame_err_o <= 1'b0;
    end else if (!enable) begin
      state       <= RX_IDLE;
      shifter     <= '0;
      bit_cnt     <= '0;
      valid_o     <= 1'b0;
      frame_err_o <= 1'b0;
    end else begin
      if (valid_o && ready_i) begin
        valid_o <= 1'b0;
      end

      if (bit_tick_i) begin
        unique case (state)
          RX_IDLE: begin
            frame_err_o <= 1'b0;
            if ((!valid_o || ready_i) && rx_i == 1'b0) begin
              bit_cnt <= 3'd0;
              state   <= RX_DATA;
            end
          end

          RX_DATA: begin
            shifter[bit_cnt] <= rx_i;
            if (bit_cnt == 3'd7) begin
              state <= RX_STOP;
            end else begin
              bit_cnt <= bit_cnt + 3'd1;
            end
          end

          RX_STOP: begin
            frame_err_o <= (rx_i != 1'b1);
            if (ready_i && rx_i == 1'b1) begin
              data_o  <= shifter;
              valid_o <= 1'b1;
            end
            state <= RX_IDLE;
          end

          default: state <= RX_IDLE;
        endcase
      end
    end
  end

endmodule
