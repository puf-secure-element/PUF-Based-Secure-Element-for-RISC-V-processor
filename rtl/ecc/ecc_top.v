module ecc_top (
    input  wire         clk_i,
    input  wire         rst_n_i,
    input  wire         mode_i,       // 0: Sinh Helper Data (Enroll), 1: Khôi phục khóa (Reconstruct)
    input  wire [511:0] raw_resp_i,   // Dữ liệu thô từ PUF
    input  wire [95:0]  helper_in_i,  // Helper Data từ Flash ngoài đưa vào
    input  wire         helper_val_i, // Tín hiệu báo Helper Data từ Flash đã sẵn sàng/hợp lệ
    
    output reg  [95:0]  helper_out_o, // Chuyển thành reg để đồng bộ xung nhịp
    output reg  [511:0] corr_resp_o,  // Chuyển thành reg để xuất ổn định sau 1 clock
    output reg          corr_resp_val_o // Tín hiệu Valid báo cho SHA-256 dữ liệu đã sạch lỗi
);

    // 1. THANH GHI NỘI BỘ để chốt giữ Helper Data ổn định 
    reg [95:0] helper_reg;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            helper_reg <= 96'h0;
        end else if (helper_val_i) begin
            helper_reg <= helper_in_i; // Chốt giữ Helper Data khi có tín hiệu Valid từ Flash
        end
    end

    // Các đường dây trung gian kết nối các khối Hamming
    wire [95:0]  calc_helper;
    wire [511:0] decoded_resp;
    
    // Vòng lặp generate 16 phân đoạn song song
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ecc_segments
            
            hamming_encoder_32 enc_inst (
                .data_i  (raw_resp_i[i*32 +: 32]),
                .parity_o(calc_helper[i*6 +: 6])
            );
            
            hamming_decoder_32 dec_inst (
                .noisy_data_i(raw_resp_i[i*32 +: 32]),
                // Sử dụng Helper Data đã được chốt giữ ổn định trong thanh ghi helper_reg
                .parity_i    (helper_reg[i*6 +: 6]), 
                .corr_data_o (decoded_resp[i*32 +: 32])
            );
            
        end
    endgenerate

    // 2. ĐỒNG BỘ HÓA ĐẦU RA VÀ TẠO TÍN HIỆU VALID 
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            corr_resp_o     <= 512'h0;
            helper_out_o    <= 96'h0;
            corr_resp_val_o <= 1'b0;
        end else begin
            // Đăng ký (Register) đầu ra sau 1 chu kỳ clock để triệt tiêu nhiễu động
            corr_resp_o  <= (mode_i == 1'b1) ? decoded_resp : raw_resp_i;
            helper_out_o <= calc_helper;
            
            // Tạo tín hiệu báo dữ liệu đầu ra hợp lệ cho khối SHA-256 phía sau
            if (mode_i == 1'b1) begin
                corr_resp_val_o <= helper_val_i; // Chỉ báo Valid khi Helper Data đã nạp xong
            end else begin
                corr_resp_val_o <= 1'b1; // Chế độ enroll luôn báo sẵn sàng sau 1 clock
            end
        end
    end

endmodule