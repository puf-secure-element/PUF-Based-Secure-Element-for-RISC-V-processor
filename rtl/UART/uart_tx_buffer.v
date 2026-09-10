module uart_tx_buffer (
    input wire          clk,
    input wire          rst_n,
    input wire [127:0]  encrypted_plaintext,
    input wire          encrypted_plaintext_valid,
    input wire [95:0]   enroll_helper,
    input wire [255:0]  enroll_key,
    input wire          enroll_response_valid,
    input wire          tx_full_status,
    output reg  [7:0]   tx_data,
    output reg          tx_wr,
    output reg          tx_busy
);

    localparam AUTH_FRAME_BYTES = 6'd21;
    localparam ENROLL_FRAME_BYTES = 6'd49;
    reg [127:0] tx_shift;
    reg [95:0]  helper_shift;
    reg [255:0] key_shift;
    reg         enroll_active;
    reg [5:0]   tx_count;
    reg [7:0]   tx_crc;
    reg         tx_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift  <= 128'h0;
            helper_shift <= 96'h0;
            key_shift <= 256'h0;
            enroll_active <= 1'b0;
            tx_count  <= 6'd0;
            tx_crc    <= 8'h0;
            tx_active <= 1'b0;
            tx_data   <= 8'h0;
            tx_wr     <= 1'b0;
            tx_busy   <= 1'b0;
        end else if (!tx_active) begin
            tx_wr <= 1'b0;
            if (enroll_response_valid) begin
                helper_shift <= enroll_helper;
                key_shift <= enroll_key;
                tx_count <= 6'd0;
                tx_crc <= enroll_helper[95:88] ^ enroll_helper[87:80] ^
                          enroll_helper[79:72] ^ enroll_helper[71:64] ^
                          enroll_helper[63:56] ^ enroll_helper[55:48] ^
                          enroll_helper[47:40] ^ enroll_helper[39:32] ^
                          enroll_helper[31:24] ^ enroll_helper[23:16] ^
                          enroll_helper[15:8] ^ enroll_helper[7:0] ^
                          enroll_key[255:248] ^ enroll_key[247:240] ^
                          enroll_key[239:232] ^ enroll_key[231:224] ^
                          enroll_key[223:216] ^ enroll_key[215:208] ^
                          enroll_key[207:200] ^ enroll_key[199:192] ^
                          enroll_key[191:184] ^ enroll_key[183:176] ^
                          enroll_key[175:168] ^ enroll_key[167:160] ^
                          enroll_key[159:152] ^ enroll_key[151:144] ^
                          enroll_key[143:136] ^ enroll_key[135:128] ^
                          enroll_key[127:120] ^ enroll_key[119:112] ^
                          enroll_key[111:104] ^ enroll_key[103:96] ^
                          enroll_key[95:88] ^ enroll_key[87:80] ^
                          enroll_key[79:72] ^ enroll_key[71:64] ^
                          enroll_key[63:56] ^ enroll_key[55:48] ^
                          enroll_key[47:40] ^ enroll_key[39:32] ^
                          enroll_key[31:24] ^ enroll_key[23:16] ^
                          enroll_key[15:8] ^ enroll_key[7:0];
                enroll_active <= 1'b1;
                tx_active <= 1'b1;
                tx_busy <= 1'b1;
            end else if (encrypted_plaintext_valid) begin
                tx_shift  <= encrypted_plaintext;
                tx_crc    <= encrypted_plaintext[127:120];
                tx_count  <= 6'd0;
                enroll_active <= 1'b0;
                tx_active <= 1'b1;
                tx_busy   <= 1'b1;
            end else begin
                tx_busy <= 1'b0;
            end
        end else if (!tx_full_status) begin
            case (tx_count)
                6'd0:  tx_data <= 8'h02;
                6'd1:  tx_data <= enroll_active ? 8'h81 : 8'h82;
                6'd2:  tx_data <= enroll_active ? 8'd28 : 8'd16;
                6'd3:  tx_data <= enroll_active ? helper_shift[95:88] : tx_shift[127:120];
                6'd4:  tx_data <= enroll_active ? helper_shift[87:80] : tx_shift[119:112];
                6'd5:  tx_data <= enroll_active ? helper_shift[79:72] : tx_shift[111:104];
                6'd6:  tx_data <= enroll_active ? helper_shift[71:64] : tx_shift[103:96];
                6'd7:  tx_data <= enroll_active ? helper_shift[63:56] : tx_shift[95:88];
                6'd8:  tx_data <= enroll_active ? helper_shift[55:48] : tx_shift[87:80];
                6'd9:  tx_data <= enroll_active ? helper_shift[47:40] : tx_shift[79:72];
                6'd10: tx_data <= enroll_active ? helper_shift[39:32] : tx_shift[71:64];
                6'd11: tx_data <= enroll_active ? helper_shift[31:24] : tx_shift[63:56];
                6'd12: tx_data <= enroll_active ? helper_shift[23:16] : tx_shift[55:48];
                6'd13: tx_data <= enroll_active ? helper_shift[15:8] : tx_shift[47:40];
                6'd14: tx_data <= enroll_active ? helper_shift[7:0] : tx_shift[39:32];
                6'd15: tx_data <= enroll_active ? key_shift[255:248] : tx_shift[31:24];
                6'd16: tx_data <= enroll_active ? key_shift[247:240] : tx_shift[23:16];
                6'd17: tx_data <= enroll_active ? key_shift[239:232] : tx_shift[15:8];
                6'd18: tx_data <= enroll_active ? key_shift[231:224] : tx_shift[7:0];
                6'd19: tx_data <= enroll_active ? key_shift[223:216] : tx_crc;
                6'd20: tx_data <= enroll_active ? key_shift[215:208] : 8'h03;
                6'd21: tx_data <= enroll_active ? key_shift[207:200] : 8'h00;
                6'd22: tx_data <= enroll_active ? key_shift[199:192] : 8'h00;
                6'd23: tx_data <= enroll_active ? key_shift[191:184] : 8'h00;
                6'd24: tx_data <= enroll_active ? key_shift[183:176] : 8'h00;
                6'd25: tx_data <= enroll_active ? key_shift[175:168] : 8'h00;
                6'd26: tx_data <= enroll_active ? key_shift[167:160] : 8'h00;
                6'd27: tx_data <= enroll_active ? key_shift[159:152] : 8'h00;
                6'd28: tx_data <= enroll_active ? key_shift[151:144] : 8'h00;
                6'd29: tx_data <= enroll_active ? key_shift[143:136] : 8'h00;
                6'd30: tx_data <= enroll_active ? key_shift[135:128] : 8'h00;
                6'd31: tx_data <= enroll_active ? key_shift[127:120] : 8'h00;
                6'd32: tx_data <= enroll_active ? key_shift[119:112] : 8'h00;
                6'd33: tx_data <= enroll_active ? key_shift[111:104] : 8'h00;
                6'd34: tx_data <= enroll_active ? key_shift[103:96] : 8'h00;
                6'd35: tx_data <= enroll_active ? key_shift[95:88] : 8'h00;
                6'd36: tx_data <= enroll_active ? key_shift[87:80] : 8'h00;
                6'd37: tx_data <= enroll_active ? key_shift[79:72] : 8'h00;
                6'd38: tx_data <= enroll_active ? key_shift[71:64] : 8'h00;
                6'd39: tx_data <= enroll_active ? key_shift[63:56] : 8'h00;
                6'd40: tx_data <= enroll_active ? key_shift[55:48] : 8'h00;
                6'd41: tx_data <= enroll_active ? key_shift[47:40] : 8'h00;
                6'd42: tx_data <= enroll_active ? key_shift[39:32] : 8'h00;
                6'd43: tx_data <= enroll_active ? key_shift[31:24] : 8'h00;
                6'd44: tx_data <= enroll_active ? key_shift[23:16] : 8'h00;
                6'd45: tx_data <= enroll_active ? key_shift[15:8] : 8'h00;
                6'd46: tx_data <= enroll_active ? key_shift[7:0] : 8'h00;
                6'd47: tx_data <= enroll_active ? tx_crc : 8'h00;
                default: tx_data <= 8'h03;
            endcase
            tx_wr <= 1'b1;

            if (!enroll_active && tx_count >= 6'd3 && tx_count <= 6'd18) begin
                if (tx_count < 6'd18)
                    tx_crc <= tx_crc ^ tx_shift[119:112];
                tx_shift <= {tx_shift[119:0], 8'h0};
            end

            if ((!enroll_active && tx_count == AUTH_FRAME_BYTES - 1'b1) ||
                (enroll_active && tx_count == ENROLL_FRAME_BYTES - 1'b1)) begin
                tx_active <= 1'b0;
                tx_busy   <= 1'b0;
                enroll_active <= 1'b0;
                tx_count  <= 6'd0;
            end else begin
                tx_count <= tx_count + 1'b1;
            end
        end else begin
            tx_wr <= 1'b0;
        end
    end
endmodule
