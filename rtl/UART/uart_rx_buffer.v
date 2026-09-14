module uart_rx_buffer #(
    // Inter-byte silence (in clk cycles) that marks the start of a brand-new
    // 16-byte transaction. Must be longer than the gap between two bytes of
    // the SAME burst (near 0 for a back-to-back TX) and shorter than the
    // gap a host leaves *between* separate sends (always at least one byte
    // time in practice). At 50 MHz / 115200 8N1 one byte time is ~4340
    // cycles, so 8192 (~2 byte times, ~164us) is a safe default; retune if
    // HCLK or the UART baud divisor changes.
    parameter IDLE_CYCLES = 16'd8192
) (
    input wire          clk,
    input wire          rst_n,

    input wire          rx_wr,
    input wire  [7:0]   rx_data,

    output reg          plaintext_valid,
    output reg  [127:0] plaintext
);

  reg [127:0] rx_shift;
  reg [3:0]   rx_count;
  reg [15:0]  idle_cnt;

  // Free-running silence timer: cleared on every received byte, saturates
  // instead of wrapping so a long-idle line doesn't alias back to "busy".
  always @(posedge clk or negedge rst_n)
    begin
      if (!rst_n)
        idle_cnt <= 16'h0;
      else if (rx_wr)
        idle_cnt <= 16'h0;
      else if (idle_cnt != {16{1'b1}})
        idle_cnt <= idle_cnt + 16'h1;
    end

  // A byte that arrives after >= IDLE_CYCLES of silence starts a fresh
  // frame: any partially-accumulated bytes from a previous, never-completed
  // transaction are discarded instead of being silently concatenated with
  // unrelated bytes from this new one. This is what makes each 16-byte send
  // self-contained regardless of anything sent earlier in the session.
  wire frame_break = (idle_cnt >= IDLE_CYCLES) && (rx_count != 4'h0);

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
          if (frame_break)
            begin
              // Discard the stale partial block; this byte is byte 0 of a
              // new transaction.
              rx_shift          <= {120'h0, rx_data};
              rx_count          <= 4'h1;
              plaintext_valid   <= 1'b0;
            end
          else if (rx_count == 4'd15)
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