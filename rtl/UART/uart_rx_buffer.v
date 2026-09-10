module uart_rx_buffer (
    input wire          clk,
    input wire          rst_n,

    input wire          rx_wr,
    input wire  [7:0]   rx_data,

    output reg          plaintext_valid,
    output reg  [127:0] plaintext
);

  reg [127:0] rx_shift;
  reg [3:0]   rx_count;
 
  always @(posedge clk or negedge rst_n)
    begin
      if (!rst_n)
        begin
          rx_shift          <= 128'h0;
          rx_count          <= 4'h0;
          plaintext         <= 128'h0;
          plaintext_valid   <= 1'b0;
        end
      else if (rx_wr)
        begin
          if (rx_count == 4'd15)
            begin
              // 16th byte completes the 128-bit block: output it, then
              // reset the accumulation buffer and counter.
              plaintext         <= {rx_shift[119:0], rx_data};
              plaintext_valid   <= 1'b1;
              rx_shift          <= 128'h0;
              rx_count          <= 4'h0;
            end
          else
            begin
              rx_shift          <= {rx_shift[119:0], rx_data};
              rx_count          <= rx_count + 4'h1;
              plaintext_valid   <= 1'b0;
            end
        end
      else
        begin
          // After a full 128-bit block is latched, clear the stale payload so a
          // new UART frame can be accepted on the next transaction.
          if (plaintext_valid)
            plaintext <= 128'h0;
          plaintext_valid <= 1'b0;
        end
    end

endmodule