module uart_tx_buffer (
    input wire          clk,
    input wire          rst_n,

    input  wire [127:0] encrypted_plaintext,
    input  wire         encrypted_plaintext_valid,
    input  wire         tx_full_status,

    output reg  [7:0]   tx_data,
    output reg          tx_wr,
    output reg          tx_busy
);

    reg [127:0] tx_shift;
    reg [3:0]   tx_count;
    reg         tx_active;
    
    always @(posedge clk or negedge rst_n)
        begin
        if (~rst_n)
            begin
            tx_shift  <= 128'h0;
            tx_count  <= 4'h0;
            tx_active <= 1'b0;
            tx_data   <= 8'h00;
            tx_wr     <= 1'b0;
            tx_busy   <= 1'b0;
            end
        else if (!tx_active)
            begin
            tx_wr <= 1'b0;
            if (encrypted_plaintext_valid)
                begin
                // Latch the new block and send its first byte right away if
                // the TX FIFO can accept it.
                tx_active <= 1'b1;
                tx_busy   <= 1'b1;
                tx_count  <= 4'h1;
                if (!tx_full_status)
                    begin
                    tx_data  <= encrypted_plaintext[127:120];
                    tx_wr    <= 1'b1;
                    tx_shift <= {encrypted_plaintext[119:0], 8'h00};
                    end
                else
                    begin
                    // Hold the whole block; first byte gets sent once space
                    // frees up (handled by the tx_active branch below).
                    tx_shift <= encrypted_plaintext;
                    tx_count <= 4'h0;
                    end
                end
            else
                begin
                tx_busy <= 1'b0;
                end
            end
        else
            begin
            // tx_active: walk out the remaining bytes
            if (!tx_full_status)
                begin
                tx_data  <= tx_shift[127:120];
                tx_wr    <= 1'b1;
                tx_shift <= {tx_shift[119:0], 8'h00};
    
                if (tx_count == 4'd15)
                    begin
                    tx_active <= 1'b0;
                    // NOTE: tx_busy is intentionally NOT cleared here. It is
                    // read by uart_top's arbitration mux
                    // (tx_wr = hw_tx_busy ? hw_tx_wr : cpu_tx_wr) in the very
                    // same cycle this last tx_wr pulse becomes visible. If
                    // tx_busy dropped in lockstep with tx_active here, the
                    // mux would see busy=0 and wr=1 simultaneously and route
                    // this final byte to cpu_tx_wr (0) instead of hw_tx_wr
                    // (1) -- silently dropping the 16th byte of every block
                    // (confirmed in simulation: only 15/16 bytes reached the
                    // FIFO with the old code). Leaving tx_busy asserted here
                    // lets it fall through to the !tx_active branch below,
                    // which clears it one cycle later -- after the mux has
                    // already let this last write through.
                    tx_count  <= 4'h0;
                    end
                else
                    begin
                    tx_count <= tx_count + 4'h1;
                    end
                end
            else
                begin
                tx_wr <= 1'b0;
                end
            end
        end

endmodule