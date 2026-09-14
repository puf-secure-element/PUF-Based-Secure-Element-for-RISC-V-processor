module axi_reg_bank (
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

    // Giao tiếp với FSM & Core
    output wire         reg_start,          
    output wire         soft_reset,
    input  wire         hw_busy,            
    input  wire         hw_done_pulse,      
    input  wire         hw_error_pulse,     
    
    // Tín hiệu cấu hình xuất xuống Core
    output wire [15:0]  reg_puf_challenge,
    output wire [31:0]  reg_puf_window,
    output wire         reg_ecc_mode,
    output wire [95:0]  reg_ecc_helper,      // Dây xuất Helper Data
    output wire         reg_aes_decrypt_en,
    output wire         reg_aes_encrypt_en,
    output wire [127:0] reg_aes_plaintext,
    output wire [127:0] reg_aes_ciphertext,
    input  wire [127:0] hw_aes_dout,

    // NEW: hardware-side plaintext load from UART RX (bypasses AXI writes)
    input  wire         hw_pt_load_valid,
    input  wire [127:0] hw_pt_load_data,

    // NEW: ECC helper data (generated during Enrollment) -- read-only for CPU
    input  wire [95:0]  hw_ecc_helper_out,

    // NEW: SHA-256 derived key -- read-only for CPU, reported as the
    // Enroll "key" field
    input  wire [255:0] hw_sha_key_out,

    // NEW: manual 16-byte UART TX trigger, for sending the Enroll response
    // frame. Bypasses AES entirely -- reuses the same uart_tx_buffer
    // hardware path already proven reliable for the AES auto-TX block (same
    // 16-byte-at-a-time walk-out, same tx_busy handshake). Firmware loads
    // MANUAL_TX_0..3, writes 1 to MANUAL_TX_CTRL, then polls MANUAL_TX_STAT
    // (hw_uart_tx_busy) until it drops before loading/sending the next block.
    input  wire         hw_uart_tx_busy,
    output wire         manual_tx_start,
    output wire [127:0] manual_tx_data
);

    // =========================================================================
    // PARAMETER HÓA ĐỊA CHỈ 
    // =========================================================================
    localparam SHA_ADDR_CTRL   = 10'h000; // Dùng làm thanh ghi Master Start/Reset
    localparam SHA_ADDR_STATUS = 10'h004; // Chứa cờ Busy, Done, Error
    localparam AES_ADDR_CTRL   = 10'h008; // Bit 0: Decrypt, Bit 1: Encrypt
    localparam ECC_ADDR_CTRL   = 10'h00C; // Bit 0: Mode (0: Enroll, 1: Recon)
    localparam PUF_ADDR_CTRL   = 10'h010; // Giữ lại theo spec
    
    // Các thanh ghi phụ trợ cho PUF
    localparam PUF_CHLG        = 10'h014;
    localparam PUF_WIND        = 10'h018;

    // Vùng nhớ 128-bit cho Plaintext
    localparam AES_PT_0        = 10'h020;
    localparam AES_PT_1        = 10'h024;
    localparam AES_PT_2        = 10'h028;
    localparam AES_PT_3        = 10'h02C;

    // Vùng nhớ 128-bit cho Ciphertext
    localparam AES_CT_0        = 10'h030;
    localparam AES_CT_1        = 10'h034;
    localparam AES_CT_2        = 10'h038;
    localparam AES_CT_3        = 10'h03C;

    // Vùng nhớ 128-bit cho Output
    localparam AES_OUT_0       = 10'h040;
    localparam AES_OUT_1       = 10'h044;
    localparam AES_OUT_2       = 10'h048;
    localparam AES_OUT_3       = 10'h04C;

    // Vùng nhớ 96-bit cho ECC Helper Data
    localparam ECC_HELPER_0    = 10'h050;
    localparam ECC_HELPER_1    = 10'h054;
    localparam ECC_HELPER_2    = 10'h058;

    // Vùng nhớ 96-bit ĐỌC helper data thật do ECC tính ra lúc Enrollment
    // (khác với ECC_HELPER_0..2 ở trên vốn là đầu vào helper_in_i cho chế
    // độ Reconstruction, do CPU/host ghi xuống).
    localparam HELPER_OUT_0    = 10'h060;
    localparam HELPER_OUT_1    = 10'h064;
    localparam HELPER_OUT_2    = 10'h068;

    // Vùng nhớ 128-bit staging cho khối gửi UART thủ công (Enroll response)
    localparam MANUAL_TX_0     = 10'h070;
    localparam MANUAL_TX_1     = 10'h074;
    localparam MANUAL_TX_2     = 10'h078;
    localparam MANUAL_TX_3     = 10'h07C;
    localparam MANUAL_TX_CTRL  = 10'h080; // Ghi bit0=1 -> xung 1 chu kỳ "gửi ngay"
    localparam MANUAL_TX_STAT  = 10'h084; // Đọc bit0 = đang bận gửi (tx_busy)

    // Vùng nhớ 256-bit ĐỌC khóa SHA-256 dùng làm "key" báo cáo trong Enroll
    localparam KEY_OUT_0       = 10'h090;
    localparam KEY_OUT_1       = 10'h094;
    localparam KEY_OUT_2       = 10'h098;
    localparam KEY_OUT_3       = 10'h09C;
    localparam KEY_OUT_4       = 10'h0A0;
    localparam KEY_OUT_5       = 10'h0A4;
    localparam KEY_OUT_6       = 10'h0A8;
    localparam KEY_OUT_7       = 10'h0AC;

    // Byte CRC (XOR-fold phần cứng của toàn bộ 44 byte payload Enroll:
    // 12 byte helper + 32 byte key) -- tính sẵn bằng tổ hợp logic để
    // firmware không cần viết vòng lặp XOR bằng tay.
    localparam ENROLL_CRC      = 10'h0B0;

    localparam ADDR_ID         = 10'h0F8;
    localparam ADDR_VERSION    = 10'h0FC;

    // =========================================================================
    // 1. AXI WRITE CHANNEL HANDSHAKE 
    // =========================================================================
    reg [31:0] axi_awaddr;
    reg        axi_awready, axi_wready, axi_bvalid;
    reg [1:0]  axi_bresp;
    reg        aw_latch_flag, w_latch_flag;
    reg [31:0] axi_wdata_reg;
    reg [3:0]  axi_wstrb_reg;

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_awready <= 1'b0; axi_awaddr <= 32'h0; aw_latch_flag <= 1'b0;
        end else begin
            if (~axi_awready && s_axi_awvalid && ~aw_latch_flag) begin
                axi_awready <= 1'b1; axi_awaddr <= s_axi_awaddr; aw_latch_flag <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                aw_latch_flag <= 1'b0; axi_awready <= 1'b0;
            end else axi_awready <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_wready <= 1'b0; axi_wdata_reg <= 32'h0; axi_wstrb_reg <= 4'h0; w_latch_flag <= 1'b0;
        end else begin
            if (~axi_wready && s_axi_wvalid && ~w_latch_flag) begin
                axi_wready <= 1'b1; axi_wdata_reg <= s_axi_wdata; axi_wstrb_reg <= s_axi_wstrb; w_latch_flag <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                w_latch_flag <= 1'b0; axi_wready <= 1'b0;
            end else axi_wready <= 1'b0;
        end
    end

    wire slv_reg_wren = aw_latch_flag && w_latch_flag && ~axi_bvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_bvalid <= 1'b0; axi_bresp <= 2'b00;
        end else begin
            if (slv_reg_wren && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                // Chặn ghi vào vùng Output (0x40 -> 0x4C)
                if (axi_awaddr[7:0] >= AES_OUT_0 && axi_awaddr[7:0] <= AES_OUT_3) 
                    axi_bresp <= 2'b10; 
                else 
                    axi_bresp <= 2'b00;
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 2. REGISTER MAP LOGIC
    // =========================================================================
    assign reg_start  = slv_reg_wren && (axi_awaddr[7:0] == SHA_ADDR_CTRL) && axi_wstrb_reg[0] && axi_wdata_reg[0];
    assign soft_reset = slv_reg_wren && (axi_awaddr[7:0] == SHA_ADDR_CTRL) && axi_wstrb_reg[0] && axi_wdata_reg[1];

    reg [15:0]  puf_chlg_reg;
    reg [31:0]  puf_wind_reg;
    reg [1:0]   aes_ctrl_reg;
    reg         ecc_ctrl_reg; 
    
    reg [31:0]  aes_pt_reg [0:3];
    reg [31:0]  aes_ct_reg [0:3];
    reg [31:0]  ecc_helper_reg [0:2]; // Thanh ghi Helper Data
    reg [127:0] aes_dout_reg;
    reg [31:0]  manual_tx_reg [0:3]; // Thanh ghi staging cho gửi UART thủ công

    assign manual_tx_start = slv_reg_wren && (axi_awaddr[7:0] == MANUAL_TX_CTRL) && axi_wstrb_reg[0] && axi_wdata_reg[0];
    assign manual_tx_data  = {manual_tx_reg[3], manual_tx_reg[2], manual_tx_reg[1], manual_tx_reg[0]};

    // NEW: CRC = XOR-fold 44 byte payload Enroll (12 byte helper + 32 byte
    // key). Thuần tổ hợp, luôn "sẵn sàng" ngay khi helper/key có giá trị --
    // XOR có tính giao hoán/kết hợp nên thứ tự gộp byte không quan trọng,
    // miễn firmware gửi đúng tập 44 byte này đi (thứ tự gửi tùy ý).
    wire [351:0] enroll_payload_bits = {hw_sha_key_out, hw_ecc_helper_out};
    reg  [7:0]   enroll_crc;
    integer      crc_i;
    always @(*) begin
        enroll_crc = 8'h00;
        for (crc_i = 0; crc_i < 44; crc_i = crc_i + 1)
            enroll_crc = enroll_crc ^ enroll_payload_bits[crc_i*8 +: 8];
    end

    reg status_done_reg;
    reg status_error_reg;
    
    assign irq = status_done_reg | status_error_reg;
    
    integer i;

    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            puf_chlg_reg     <= 16'hA5A5;
            puf_wind_reg     <= 32'd50;
            aes_ctrl_reg     <= 2'b01; 
            ecc_ctrl_reg     <= 1'b1;  
            
            aes_pt_reg[0] <= 32'h0; aes_pt_reg[1] <= 32'h0; aes_pt_reg[2] <= 32'h0; aes_pt_reg[3] <= 32'h0;
            aes_ct_reg[0] <= 32'h0; aes_ct_reg[1] <= 32'h0; aes_ct_reg[2] <= 32'h0; aes_ct_reg[3] <= 32'h0;
            ecc_helper_reg[0] <= 32'h0; ecc_helper_reg[1] <= 32'h0; ecc_helper_reg[2] <= 32'h0;
            manual_tx_reg[0] <= 32'h0; manual_tx_reg[1] <= 32'h0; manual_tx_reg[2] <= 32'h0; manual_tx_reg[3] <= 32'h0;
            
            status_done_reg  <= 1'b0;
            status_error_reg <= 1'b0;
            aes_dout_reg     <= 128'h0;
        end else begin
            // Hardware Status Logic
            if (reg_start) begin
                status_done_reg  <= 1'b0;
                status_error_reg <= 1'b0;
            end else begin
                if (hw_error_pulse) status_error_reg <= 1'b1;
                else if (hw_done_pulse) begin
                    status_done_reg <= 1'b1;
                    aes_dout_reg    <= hw_aes_dout;
                end
                
                // Write-1-to-Clear cho Status
                if (slv_reg_wren && axi_bresp == 2'b00 && axi_awaddr[7:0] == SHA_ADDR_STATUS) begin
                    if (axi_wstrb_reg[0]) begin
                        if (axi_wdata_reg[1]) status_done_reg  <= 1'b0; 
                        if (axi_wdata_reg[2]) status_error_reg <= 1'b0; 
                    end
                end
            end

            // NEW: hardware load of plaintext from UART RX buffer (128-bit block
            // complete). Given priority over a same-cycle CPU write to AES_PT_*.
            if (hw_pt_load_valid) begin
                {aes_pt_reg[3], aes_pt_reg[2], aes_pt_reg[1], aes_pt_reg[0]} <= hw_pt_load_data;
            end

            // Xử lý Write từ CPU
            if (slv_reg_wren && axi_bresp == 2'b00) begin
                case (axi_awaddr[7:0])
                    AES_ADDR_CTRL: if (axi_wstrb_reg[0]) aes_ctrl_reg <= axi_wdata_reg[1:0];
                    ECC_ADDR_CTRL: if (axi_wstrb_reg[0]) ecc_ctrl_reg <= axi_wdata_reg[0];
                    PUF_CHLG: begin
                        if (axi_wstrb_reg[0]) puf_chlg_reg[7:0]  <= axi_wdata_reg[7:0];
                        if (axi_wstrb_reg[1]) puf_chlg_reg[15:8] <= axi_wdata_reg[15:8];
                    end
                    PUF_WIND: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) puf_wind_reg[(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    
                    AES_PT_0: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_pt_reg[0][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_PT_1: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_pt_reg[1][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_PT_2: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_pt_reg[2][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_PT_3: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_pt_reg[3][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    
                    AES_CT_0: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_ct_reg[0][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_CT_1: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_ct_reg[1][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_CT_2: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_ct_reg[2][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    AES_CT_3: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_ct_reg[3][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    
                    ECC_HELPER_0: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) ecc_helper_reg[0][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ECC_HELPER_1: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) ecc_helper_reg[1][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ECC_HELPER_2: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) ecc_helper_reg[2][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];

                    MANUAL_TX_0: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) manual_tx_reg[0][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    MANUAL_TX_1: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) manual_tx_reg[1][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    MANUAL_TX_2: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) manual_tx_reg[2][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    MANUAL_TX_3: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) manual_tx_reg[3][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // 3. AXI READ CHANNEL
    // =========================================================================
    reg [31:0] axi_araddr;
    reg        axi_arready;
    reg [31:0] axi_rdata;
    reg [1:0]  axi_rresp;
    reg        axi_rvalid;

    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;

    wire ar_hs = ~axi_arready && s_axi_arvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_arready <= 1'b0; axi_araddr  <= 32'h0;
        end else if (ar_hs) begin
            axi_arready <= 1'b1; axi_araddr  <= s_axi_araddr;
        end else axi_arready <= 1'b0;
    end

    wire slv_reg_rden = axi_arready && s_axi_arvalid && ~axi_rvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_rvalid <= 1'b0; axi_rresp <= 2'b00; axi_rdata <= 32'h0;
        end else begin
            if (slv_reg_rden) begin
                axi_rvalid <= 1'b1; axi_rresp <= 2'b00; 
                case (axi_araddr[7:0])
                    SHA_ADDR_CTRL:   axi_rdata <= 32'h0;
                    SHA_ADDR_STATUS: axi_rdata <= {29'h0, status_error_reg, status_done_reg, hw_busy}; 
                    AES_ADDR_CTRL:   axi_rdata <= {30'h0, aes_ctrl_reg};
                    ECC_ADDR_CTRL:   axi_rdata <= {31'h0, ecc_ctrl_reg};
                    PUF_CHLG:        axi_rdata <= {16'h0, puf_chlg_reg}; 
                    PUF_WIND:        axi_rdata <= puf_wind_reg;
                    AES_PT_0:        axi_rdata <= aes_pt_reg[0];
                    AES_PT_1:        axi_rdata <= aes_pt_reg[1];
                    AES_PT_2:        axi_rdata <= aes_pt_reg[2];
                    AES_PT_3:        axi_rdata <= aes_pt_reg[3];
                    AES_CT_0:        axi_rdata <= aes_ct_reg[0];
                    AES_CT_1:        axi_rdata <= aes_ct_reg[1];
                    AES_CT_2:        axi_rdata <= aes_ct_reg[2];
                    AES_CT_3:        axi_rdata <= aes_ct_reg[3];
                    ECC_HELPER_0:    axi_rdata <= ecc_helper_reg[0];
                    ECC_HELPER_1:    axi_rdata <= ecc_helper_reg[1];
                    ECC_HELPER_2:    axi_rdata <= ecc_helper_reg[2];
                    AES_OUT_0:       axi_rdata <= aes_dout_reg[31:0];
                    AES_OUT_1:       axi_rdata <= aes_dout_reg[63:32];
                    AES_OUT_2:       axi_rdata <= aes_dout_reg[95:64];
                    AES_OUT_3:       axi_rdata <= aes_dout_reg[127:96];
                    HELPER_OUT_0:    axi_rdata <= hw_ecc_helper_out[31:0];
                    HELPER_OUT_1:    axi_rdata <= hw_ecc_helper_out[63:32];
                    HELPER_OUT_2:    axi_rdata <= hw_ecc_helper_out[95:64];
                    MANUAL_TX_0:     axi_rdata <= manual_tx_reg[0];
                    MANUAL_TX_1:     axi_rdata <= manual_tx_reg[1];
                    MANUAL_TX_2:     axi_rdata <= manual_tx_reg[2];
                    MANUAL_TX_3:     axi_rdata <= manual_tx_reg[3];
                    MANUAL_TX_STAT:  axi_rdata <= {31'h0, hw_uart_tx_busy};
                    KEY_OUT_0:       axi_rdata <= hw_sha_key_out[31:0];
                    KEY_OUT_1:       axi_rdata <= hw_sha_key_out[63:32];
                    KEY_OUT_2:       axi_rdata <= hw_sha_key_out[95:64];
                    KEY_OUT_3:       axi_rdata <= hw_sha_key_out[127:96];
                    KEY_OUT_4:       axi_rdata <= hw_sha_key_out[159:128];
                    KEY_OUT_5:       axi_rdata <= hw_sha_key_out[191:160];
                    KEY_OUT_6:       axi_rdata <= hw_sha_key_out[223:192];
                    KEY_OUT_7:       axi_rdata <= hw_sha_key_out[255:224];
                    ENROLL_CRC:      axi_rdata <= {24'h0, enroll_crc};
                    ADDR_ID:         axi_rdata <= 32'h43525950; // "CRYP"
                    ADDR_VERSION:    axi_rdata <= 32'h00010000;
                    default: begin
                        axi_rdata <= 32'h0;
                        axi_rresp <= 2'b10; // SLVERR
                    end
                endcase
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Ghép dây xuất ra cho lõi phần cứng
    assign reg_puf_challenge  = puf_chlg_reg;
    assign reg_puf_window     = puf_wind_reg;
    assign reg_ecc_mode       = ecc_ctrl_reg;
    assign reg_ecc_helper     = {ecc_helper_reg[2], ecc_helper_reg[1], ecc_helper_reg[0]};
    assign reg_aes_decrypt_en = aes_ctrl_reg[0];
    assign reg_aes_encrypt_en = aes_ctrl_reg[1];
    
    assign reg_aes_plaintext  = {aes_pt_reg[3], aes_pt_reg[2], aes_pt_reg[1], aes_pt_reg[0]};
    assign reg_aes_ciphertext = {aes_ct_reg[3], aes_ct_reg[2], aes_ct_reg[1], aes_ct_reg[0]};

endmodule