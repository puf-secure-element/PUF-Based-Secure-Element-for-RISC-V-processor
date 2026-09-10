module axi_slave_top (
    input  wire         clk,
    input  wire         rst_n,

    // AXI4-Lite Slave Interface
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,

    // System Signals
    output wire         irq,
    output wire [127:0] data_out,

    // NEW: UART <-> AES streaming interface
    input  wire [127:0] uart_plaintext,       // from uart_rx_buffer
    input  wire         uart_plaintext_valid, // from uart_rx_buffer (1-cycle pulse)
    input  wire         uart_enroll_valid,
    output wire         aes_block_valid,       // to uart_tx_buffer (1-cycle pulse, data_out is valid)
    output wire         enroll_block_valid,
    output wire [95:0]  enroll_helper,
    output wire [255:0] enroll_key
);

    wire reg_start, soft_reset;
    wire hw_busy, hw_done_pulse, hw_error_pulse;
    wire puf_start, ecc_start, sha_start, aes_start;
    wire puf_valid, ecc_valid, sha_valid, sha_error, aes_done;
    wire key_ready;
    wire enroll_mode;

    wire [15:0]  reg_puf_challenge;
    wire [31:0]  reg_puf_window;
    wire         reg_ecc_mode;
    wire [95:0]  reg_ecc_helper;
    wire         reg_aes_decrypt_en;
    wire         reg_aes_encrypt_en;
    wire [127:0] reg_aes_plaintext;
    wire [127:0] reg_aes_ciphertext;
    wire [127:0] hw_aes_dout;
    
    axi_reg_bank u_reg_bank (
        .clk                (clk),
        .rst_n              (rst_n),
        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),
        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),
        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),
        .s_axi_araddr       (s_axi_araddr),
        .s_axi_arvalid      (s_axi_arvalid),
        .s_axi_arready      (s_axi_arready),
        .s_axi_rdata        (s_axi_rdata),
        .s_axi_rresp        (s_axi_rresp),
        .s_axi_rvalid       (s_axi_rvalid),
        .s_axi_rready       (s_axi_rready),
        .irq                (irq),
        .reg_start          (reg_start),
        .soft_reset         (soft_reset),
        .hw_busy            (hw_busy),
        .hw_done_pulse      (hw_done_pulse),
        .hw_error_pulse     (hw_error_pulse),
        
        .reg_puf_challenge  (reg_puf_challenge),
        .reg_puf_window     (reg_puf_window),
        .reg_ecc_mode       (reg_ecc_mode),
        .reg_ecc_helper     (reg_ecc_helper),
        .reg_aes_decrypt_en (reg_aes_decrypt_en),
        .reg_aes_encrypt_en (reg_aes_encrypt_en),
        .reg_aes_plaintext  (reg_aes_plaintext),
        .reg_aes_ciphertext (reg_aes_ciphertext),
        .hw_aes_dout        (hw_aes_dout),

        .hw_pt_load_valid   (uart_plaintext_valid),
        .hw_pt_load_data    (uart_plaintext)
    );

    control_fsm u_fsm (
        .clk                (clk),
        .rst_n              (rst_n),
        .reg_start          (reg_start),
        .soft_reset         (soft_reset),
        .hw_busy            (hw_busy),
        .hw_done_pulse      (hw_done_pulse),
        .hw_error_pulse     (hw_error_pulse),
        .puf_start          (puf_start),
        .puf_valid          (puf_valid),
        .ecc_start          (ecc_start),
        .ecc_valid          (ecc_valid),
        .sha_start          (sha_start),
        .sha_valid          (sha_valid),
        .sha_error          (sha_error),
        .aes_start          (aes_start),
        .aes_done           (aes_done),

        .key_ready          (key_ready),
        .plaintext_ready    (uart_plaintext_valid),
        .enroll_request     (uart_enroll_valid),
        .uart_tx_valid      (aes_block_valid),
        .enroll_tx_valid    (enroll_block_valid),
        .enroll_mode        (enroll_mode)
    );

    axi_slave_core u_core (
        .clk                (clk),
        .rst_n              (rst_n),
        
        .puf_challenge      (reg_puf_challenge),
        .puf_window         (reg_puf_window),
        .ecc_mode           (enroll_mode ? 1'b0 : reg_ecc_mode),
        .ecc_helper_in      (reg_ecc_helper),
        .aes_decrypt_en     (reg_aes_decrypt_en),
        .aes_encrypt_en     (reg_aes_encrypt_en),
        .aes_plaintext      (reg_aes_plaintext),
        .aes_ciphertext     (reg_aes_ciphertext),
        
        .puf_start          (puf_start),
        .puf_valid          (puf_valid),
        .ecc_start          (ecc_start),
        .ecc_valid          (ecc_valid),
        .sha_start          (sha_start),
        .sha_valid          (sha_valid),
        .sha_error          (sha_error),
        .aes_start          (aes_start),
        .key_ready          (key_ready),
        .aes_done           (aes_done),
        .aes_dout           (hw_aes_dout)
        ,.helper_out        (enroll_helper)
        ,.key_out           (enroll_key)
    );

    assign data_out = hw_aes_dout;

endmodule