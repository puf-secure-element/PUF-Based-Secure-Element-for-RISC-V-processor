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
    input  wire [127:0] hw_aes_dout
);

    // =========================================================================
    // PARAMETER HÓA ĐỊA CHỈ 
    // =========================================================================
    localparam SHA_ADDR_CTRL   = 8'h00; // Dùng làm thanh ghi Master Start/Reset
    localparam SHA_ADDR_STATUS = 8'h04; // Chứa cờ Busy, Done, Error
    localparam AES_ADDR_CTRL   = 8'h08; // Bit 0: Decrypt, Bit 1: Encrypt
    localparam ECC_ADDR_CTRL   = 8'h0C; // Bit 0: Mode (0: Enroll, 1: Recon)
    localparam PUF_ADDR_CTRL   = 8'h10; // Giữ lại theo spec
    
    // Các thanh ghi phụ trợ cho PUF
    localparam PUF_CHLG        = 8'h14;
    localparam PUF_WIND        = 8'h18;

    // Vùng nhớ 128-bit cho Plaintext
    localparam AES_PT_0        = 8'h20;
    localparam AES_PT_1        = 8'h24;
    localparam AES_PT_2        = 8'h28;
    localparam AES_PT_3        = 8'h2C;

    // Vùng nhớ 128-bit cho Ciphertext
    localparam AES_CT_0        = 8'h30;
    localparam AES_CT_1        = 8'h34;
    localparam AES_CT_2        = 8'h38;
    localparam AES_CT_3        = 8'h3C;

    // Vùng nhớ 128-bit cho Output
    localparam AES_OUT_0       = 8'h40;
    localparam AES_OUT_1       = 8'h44;
    localparam AES_OUT_2       = 8'h48;
    localparam AES_OUT_3       = 8'h4C;
    
    // Vùng nhớ 96-bit cho ECC Helper Data
    localparam ECC_HELPER_0    = 8'h50;
    localparam ECC_HELPER_1    = 8'h54;
    localparam ECC_HELPER_2    = 8'h58;

    localparam ADDR_ID         = 8'hF8;
    localparam ADDR_VERSION    = 8'hFC;

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