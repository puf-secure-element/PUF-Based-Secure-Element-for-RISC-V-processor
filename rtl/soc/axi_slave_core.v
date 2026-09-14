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
    input  wire         key_ready,
    output wire         aes_done,

    // Dữ liệu trả về Reg Bank
    output wire [127:0] aes_dout
);

    wire [511:0]    w_puf_response;
    wire [511:0]    w_ecc_response;
    wire [255:0]    w_sha_key;
    wire [31:0]     sha_wdata;
    reg  [255:0]    key_reg;

    reg             ecc_valid_reg;

    // NEW: aes_dout latch. aes.v's own data_out/done are only valid for the
    // single cycle that done is high -- the AES core clears its internal
    // state (and hence data_out) on the very next cycle, by design (see
    // aes.v PH_DONE). But control_fsm's uart_tx_valid/hw_done_pulse are
    // *registered* outputs derived from aes_done, so they only actually
    // assert one cycle AFTER aes_done was seen -- by which point aes.v's
    // raw data_out has already gone back to 0. Anything gated on those FSM
    // pulses (UART auto-TX, and axi_reg_bank's AES_OUT_* capture) was
    // therefore always latching zero instead of the real ciphertext.
    // Fix: capture the raw AES output into a holding register on the same
    // cycle aes_done is high, and keep it stable until the next block
    // completes. Downstream consumers now read this snapshot instead of
    // racing the AES core's self-clear.
    wire [127:0]    aes_dout_raw;
    reg  [127:0]    aes_dout_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            aes_dout_latched <= 128'h0;
        else if (aes_done)
            aes_dout_latched <= aes_dout_raw;
    end

    assign aes_dout = aes_dout_latched;

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg <= 256'h0;
        end else begin
            // Additional logic if needed
            if(sha_valid) begin
                key_reg <= w_sha_key[255:0]; // Capture the lower 128 bits of the SHA key
            end
        end
    end

    // 4. AES
    // plaintext_valid = aes_start: control_fsm only pulses aes_start once it
    // has already qualified (key_ready && plaintext_pending), so this is a
    // clean 1-cycle "new block ready" strobe.
    // key_ready is the real, level-held signal from control_fsm (asserted
    // once after PUF->ECC->SHA completes and held for the device's life).
    // NOTE: the previous `sha_valid & aes_start` wiring was broken -- those
    // two pulses occur at completely different points in time and almost
    // never coincide, so AES's key-ready input never actually asserted and
    // AES never ran.
    aes u_aes (
        .clk             (clk),
        .rst_n           (rst_n),
        .decrypt         (aes_decrypt_en),  
        .encrypt         (aes_encrypt_en),
        .plaintext       (actual_aes_din), 
        .plaintext_valid (aes_start),
        .key_ready       (key_ready),
        .key_in          (key_reg),
        .data_out        (aes_dout_raw),
        .done            (aes_done)
    );

endmodule