module axi_slave_core (
    input  wire         clk,
    input  wire         rst_n,

    // Tín hiệu cấu hình từ Reg Bank
    input  wire [15:0]  puf_challenge,
    input  wire [31:0]  puf_window,
    input  wire         ecc_mode,
    input  wire [95:0]  ecc_helper_in,
    input  wire         aes_decrypt_en,
    input  wire         aes_encrypt_en,
    input  wire [127:0] aes_plaintext,
    input  wire [127:0] aes_ciphertext,

    // Tín hiệu điều khiển từ FSM
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

    wire [511:0]    w_puf_response;
    wire [511:0]    w_ecc_response;
    wire [255:0]    w_sha_key;
    wire [31:0]     sha_wdata;

    reg             ecc_valid_reg;

    assign sha_wdata = sha_start ? 32'h1 : 32'h0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ecc_valid_reg <= 1'b0;
        end else begin
            // Logic to handle the start signals and data flow
            if(ecc_valid)
                ecc_valid_reg <= 1'b1; // Capture ECC response when valid
        end
    end

    // 1. PUF
    ro_puf_core u_puf (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (puf_start),
        .measure_window  (puf_window),
        .challenge       (puf_challenge),
        .response        (w_puf_response),
        .response_ready  (puf_valid),
        .core_busy       ()
    );

    // 2. ECC
    ecc_top u_ecc (
        .clk_i           (clk),
        .rst_n_i         (rst_n),
        .mode_i          (ecc_mode),
        .start_i         (ecc_start),
        .raw_resp_i      (w_puf_response),
        .helper_in_i     (ecc_helper_in), 
        .helper_val_i    (1'b1),         
        .helper_out_o    (),         
        .corr_resp_o     (w_ecc_response),
        .corr_resp_val_o (ecc_valid)
    );

    // 3. SHA256
    sha256_top u_sha256 (
        .clk             (clk),
        .rst_n           (rst_n),
        .sel             (1'b1), 
        .we              (1'b1), 
        .addr            (8'h00),      
        .wdata           (sha_wdata),
        .rdata           (),
        .ecc_response    (w_ecc_response),
        .ecc_valid       (ecc_valid_reg),
        .error           (sha_error),
        .hash_out        (w_sha_key),
        .hash_valid      (sha_valid)
    );

    // MUX dữ liệu đầu vào cho AES: Nếu giải mã thì feed Ciphertext, ngược lại feed Plaintext
    wire [127:0] actual_aes_din = aes_decrypt_en ? aes_ciphertext : aes_plaintext;

    // 4. AES
    aes u_aes (
        .clk             (clk),
        .rst_n           (rst_n),
        .decrypt         (aes_decrypt_en),  
        .encrypt         (aes_encrypt_en),
        .plaintext       (actual_aes_din), 
        .key_is_ready    (sha_valid & aes_start), 
        .key_in          (w_sha_key),
        .data_out        (aes_dout),
        .done            (aes_done)
    );

endmodule