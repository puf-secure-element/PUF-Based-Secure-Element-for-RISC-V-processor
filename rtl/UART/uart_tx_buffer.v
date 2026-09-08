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
    
    always @(posedge pclk or negedge presetn)
        begin
        if (~presetn)
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
                    tx_busy   <= 1'b0;
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