module ecc_top (
    input  wire         clk_i,
    input  wire         rst_n_i,
    input  wire         mode_i,          // 0: Enroll (Gen helper), 1: Reconstruct
    input  wire         start_i,         // Pulse kích hoạt
    input  wire [511:0] raw_resp_i,      // Dữ liệu từ PUF
    input  wire [95:0]  helper_in_i,     // Helper data từ Flash ngoài
    input  wire         helper_val_i,    // Helper data ready (cùng clock clk_i)

    output reg  [95:0]  helper_out_o,    // Helper data xuất ra để ghi Flash
    output reg  [511:0] corr_resp_o,     // Key đã sửa lỗi đưa sang SHA-256
    output reg          corr_resp_val_o, // Báo dữ liệu corr_resp_o hợp lệ
    output reg          helper_out_val_o // Báo dữ liệu helper_out_o hợp lệ (cho Enroll)
);

    wire [95:0]  calc_helper;
    wire [511:0] decoded_resp;
    wire [95:0]  parity_for_dec;

    // Trong reconstruct mode, dùng helper_in_i từ flash ngoài
    assign parity_for_dec = helper_in_i;

    // 16 phân đoạn 32-bit = 512 bit
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ecc_segments
            hamming_encoder_32 enc_inst (
                .data_i  (raw_resp_i[i*32 +: 32]),    
                .parity_o(calc_helper[i*6 +: 6])
            );

            hamming_decoder_32 dec_inst (
                .noisy_data_i(raw_resp_i[i*32 +: 32]),
                .parity_i    (parity_for_dec[i*6 +: 6]),
                .corr_data_o (decoded_resp[i*32 +: 32])
            );
        end
    endgenerate

    // Pipeline điều khiển và chốt đầu ra
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            corr_resp_o      <= 512'h0;
            helper_out_o     <= 96'h0;
            corr_resp_val_o  <= 1'b0;
            helper_out_val_o <= 1'b0;
        end else begin
            // Mặc định hạ valid sau 1 chu kỳ clock nếu không có kích hoạt mới
            corr_resp_val_o  <= 1'b0;
            helper_out_val_o <= 1'b0;

            if (start_i) begin
                if (mode_i == 1'b0) begin
                    // --- ENROLL MODE ---
                    // Xuất helper data để ghi vào 
                    helper_out_o     <= calc_helper;
                    helper_out_val_o <= 1'b1;
                    corr_resp_o      <= raw_resp_i;
                    corr_resp_val_o  <= 1'b1;
                end else begin
                    // --- RECONSTRUCT MODE ---
                    if (helper_val_i) begin
                        corr_resp_o     <= decoded_resp;
                        corr_resp_val_o <= 1'b1;
                    end
                end
            end
        end
    end

endmodule