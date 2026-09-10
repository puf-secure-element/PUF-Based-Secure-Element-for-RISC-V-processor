module uart_rx_buffer (
    input wire          clk,
    input wire          rst_n,

    input wire          rx_wr,
    input wire  [7:0]   rx_data,

    output reg          plaintext_valid,
    output reg  [127:0] plaintext,
    output reg          enroll_valid
);

  localparam WAIT_STX = 3'd0;
  localparam READ_CMD = 3'd1;
  localparam READ_LEN = 3'd2;
  localparam READ_PAYLOAD = 3'd3;
  localparam READ_CRC = 3'd4;
  localparam READ_ETX = 3'd5;

  reg [2:0]   state;
  reg [7:0]   frame_cmd;
  reg [7:0]   frame_len;
  reg [5:0]   rx_count;
  reg [7:0]   crc_calc;
  reg [7:0]   crc_received;
  reg [127:0] payload;
 
  always @(posedge clk or negedge rst_n)
    begin
      if (!rst_n)
        begin
          state             <= WAIT_STX;
          frame_cmd         <= 8'h0;
          frame_len         <= 8'h0;
          rx_count          <= 6'd0;
          crc_calc          <= 8'h0;
          crc_received      <= 8'h0;
          payload           <= 128'h0;
          plaintext         <= 128'h0;
          plaintext_valid   <= 1'b0;
          enroll_valid      <= 1'b0;
        end
      else
        begin
          plaintext_valid <= 1'b0;
          enroll_valid <= 1'b0;
          if (rx_wr)
            begin
              case (state)
                WAIT_STX: begin
                  if (rx_data == 8'h02)
                    state <= READ_CMD;
                end
                READ_CMD: begin
                  frame_cmd <= rx_data;
                  state <= READ_LEN;
                end
                READ_LEN: begin
                  frame_len <= rx_data;
                  rx_count <= 6'd0;
                  crc_calc <= 8'h0;
                  payload <= 128'h0;
                  if (rx_data == 8'd0 && frame_cmd == 8'h01)
                    state <= READ_CRC;
                  else if (rx_data == 8'd16)
                    state <= READ_PAYLOAD;
                  else
                    state <= WAIT_STX;
                end
                READ_PAYLOAD: begin
                  if (frame_len == 8'd16) begin
                    payload <= {payload[119:0], rx_data};
                    crc_calc <= crc_calc ^ rx_data;
                  end
                  if ((frame_len == 8'd0) ||
                      (rx_count == 6'd15))
                    state <= READ_CRC;
                  else
                    rx_count <= rx_count + 1'b1;
                end
                READ_CRC: begin
                  crc_received <= rx_data;
                  state <= READ_ETX;
                end
                READ_ETX: begin
                  if (rx_data == 8'h03 &&
                      ((frame_cmd == 8'h02 && frame_len == 8'd16) ||
                       (frame_cmd == 8'h01 && frame_len == 8'd0)) &&
                      crc_received == crc_calc) begin
                    if (frame_cmd == 8'h02) begin
                      plaintext <= payload;
                      plaintext_valid <= 1'b1;
                    end else begin
                      enroll_valid <= 1'b1;
                    end
                  end
                  state <= WAIT_STX;
                end
                default: state <= WAIT_STX;
              endcase
            end
        end
    end

endmodule