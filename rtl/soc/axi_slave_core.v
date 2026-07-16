module axi_slave_core (
    input  wire         clk,
    input  wire         rst_n,

    // Dữ liệu từ Reg Bank chuyển xuống
    input  wire [15:0]  puf_challenge,
    input  wire [31:0]  puf_window,
    input  wire [127:0] aes_din,

    // Tín hiệu điều khiển từ FSM chuyển xuống
    input  wire         puf_start,
    output wire         puf_valid,
    input  wire         ecc_start,
    output wire         ecc_valid,
    input  wire         sha_start,
    output wire         sha_valid,
    output wire         sha_error,
    input  wire         aes_start,
    output wire         aes_done,

    // Dữ liệu trả về Reg Bank
    output wire [127:0] aes_dout
);

    // Mạch máu nối nội bộ giữa các IP (Giữ nguyên tên biến y hệt soc.v cũ)
    wire [511:0] puf_response;
    wire [511:0] ecc_response;
    wire [255:0] key;

    // =========================================================================
    // 1. KHỐI PUF
    // =========================================================================
    ro_puf_core puf(
        .clk(clk),
        .rst_n(rst_n),
        .start(puf_start),                  // FSM cấp xung thay cho CPU
        .measure_window(puf_window),        // Lấy từ thanh ghi thay vì 32'd50
        .challenge(puf_challenge),          // Lấy từ thanh ghi thay vì 16'hA5A5
        .response(puf_response),
        .response_ready(puf_valid),
        .core_busy()                        // Cổng trống y hệt bản gốc
    );

    // =========================================================================
    // 2. KHỐI ECC
    // =========================================================================
    ecc_top ecc(
        .clk_i(clk),
        .rst_n_i(rst_n),
        .mode_i(1'b1),                      // 1 = Reconstruction Mode
        .start_i(puf_valid),                // Nối thẳng từ puf_valid y như code soc.v cũ
        .raw_resp_i(puf_response),
        .helper_in_i(),                     // Cổng trống
        .helper_val_i(),                    // Cổng trống
        .helper_out_o(),                    // Cổng trống
        .corr_resp_o(ecc_response),
        .corr_resp_val_o(ecc_valid)
    );

    // =========================================================================
    // 3. KHỐI SHA256
    // =========================================================================
    sha256_top sha256(
        .clk(clk),
        .rst_n(rst_n),
        // Thay vì hardcode sel=1, we=1 như cũ, ta dùng xung sha_start từ FSM
        // để kích hoạt SHA băm dữ liệu an toàn.
        .sel(sha_start),             
        .we(sha_start),              
        .addr(8'h00),                       // Cấp địa chỉ ảo để IP chạy bình thường
        .wdata(32'h0000_0001),              // Cấp data ảo
        
        .ecc_response(ecc_response),
        .ecc_valid(ecc_valid),
        .rdata(),                           // Cổng trống
        .error(sha_error),
        .hash_out(key),
        .hash_valid(sha_valid)
    );

    // =========================================================================
    // 4. KHỐI AES
    // =========================================================================
    aes dut(
        .clk(clk),
        .rst_n(rst_n),
        // Chân de/en ngày xưa là logic tổ hợp, giờ thay bằng xung aes_start
        .decrypt(aes_start),         
        .encrypt(1'b0),
        
        .plaintext(aes_din),                // Data thật lấy từ Bus AXI (Flash)
        .key_is_ready(sha_valid),           // Nối thẳng từ SHA sang
        .key_in(key),                       // Nối thẳng từ SHA sang
        .data_out(aes_dout),
        .done(aes_done)
    );

endmodule