module ecc_top (
    input  wire         clk_i,
    input  wire         rst_n_i,
    input  wire         mode_i,       // 0: Sinh Helper Data (Enroll), 1: Khôi phục khóa (Reconstruct)
    input  wire [511:0] raw_resp_i,   // Dữ liệu thô từ PUF
    input  wire [95:0]  helper_in_i,  // 96-bit Helper Data đọc về từ Flash
    
    output wire [95:0]  helper_out_o, // 96-bit Helper Data sinh ra để ghi vào Flash
    output wire [511:0] corr_resp_o   // 512-bit Dữ liệu đã sạch lỗi đưa sang SHA-256
);

    // Sử dụng vòng lặp generate chuẩn Verilog-2001
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ecc_segments
            
            // Kết nối các phân đoạn của Encoder
            hamming_encoder_32 enc_inst (
                .data_i  (raw_resp_i[i*32 +: 32]),
                .parity_o(helper_out_o[i*6 +: 6])
            );
            
            // Kết nối các phân đoạn của Decoder
            hamming_decoder_32 dec_inst (
                .noisy_data_i(raw_resp_i[i*32 +: 32]),
                .parity_i    (helper_in_i[i*6 +: 6]),
                .corr_data_o (corr_resp_o[i*32 +: 32])
            );
            
        end
    endgenerate

endmodule