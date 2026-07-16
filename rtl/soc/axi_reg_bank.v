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
    output wire         irq,                // Tín hiệu ngắt

    // Giao tiếp với FSM & Core
    output wire         reg_start,          
    output wire         soft_reset,         // Reset mềm từ CPU
    input  wire         hw_busy,            
    input  wire         hw_done_pulse,      
    input  wire         hw_error_pulse,     
    
    output wire [15:0]  reg_puf_challenge,
    output wire [31:0]  reg_puf_window,
    output wire [127:0] reg_aes_din,
    input  wire [127:0] hw_aes_dout
);

    // =========================================================================
    // PARAMETER HÓA ĐỊA CHỈ (Tính năng 5)
    // =========================================================================
    localparam ADDR_CTRL      = 8'h00;
    localparam ADDR_STATUS    = 8'h04;
    localparam ADDR_PUF_CHLG  = 8'h08;
    localparam ADDR_PUF_WIND  = 8'h0C;
    localparam ADDR_AES_DIN0  = 8'h10;
    localparam ADDR_AES_DIN1  = 8'h14;
    localparam ADDR_AES_DIN2  = 8'h18;
    localparam ADDR_AES_DIN3  = 8'h1C;
    localparam ADDR_AES_DOUT0 = 8'h20;
    localparam ADDR_AES_DOUT1 = 8'h24;
    localparam ADDR_AES_DOUT2 = 8'h28;
    localparam ADDR_AES_DOUT3 = 8'h2C;
    localparam ADDR_ID        = 8'hF8;
    localparam ADDR_VERSION   = 8'hFC;

    // =========================================================================
    // 1. AXI WRITE CHANNEL HANDSHAKE
    // =========================================================================
    reg [31:0] axi_awaddr;
    reg        axi_awready;
    reg        axi_wready;
    reg [1:0]  axi_bresp;
    reg        axi_bvalid;

    reg aw_latch_flag;
    reg w_latch_flag;
    reg [31:0] axi_wdata_reg;
    reg [3:0]  axi_wstrb_reg;

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_awready   <= 1'b0;
            axi_awaddr    <= 32'h0;
            aw_latch_flag <= 1'b0;
        end else begin
            if (~axi_awready && s_axi_awvalid && ~aw_latch_flag) begin
                axi_awready   <= 1'b1;
                axi_awaddr    <= s_axi_awaddr;
                aw_latch_flag <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                aw_latch_flag <= 1'b0;
                axi_awready   <= 1'b0;
            end else begin
                axi_awready   <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_wready    <= 1'b0;
            axi_wdata_reg <= 32'h0;
            axi_wstrb_reg <= 4'h0;
            w_latch_flag  <= 1'b0;
        end else begin
            if (~axi_wready && s_axi_wvalid && ~w_latch_flag) begin
                axi_wready    <= 1'b1;
                axi_wdata_reg <= s_axi_wdata;
                axi_wstrb_reg <= s_axi_wstrb;
                w_latch_flag  <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                w_latch_flag  <= 1'b0;
                axi_wready    <= 1'b0;
            end else begin
                axi_wready    <= 1'b0;
            end
        end
    end

    wire slv_reg_wren = aw_latch_flag && w_latch_flag && ~axi_bvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (slv_reg_wren && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                // Chặn ghi vào vùng Read-Only AES_DOUT (0x20 -> 0x2C)
                if (axi_awaddr[7:0] >= ADDR_AES_DOUT0 && axi_awaddr[7:0] <= ADDR_AES_DOUT3) 
                    axi_bresp <= 2'b10; // SLVERR
                else 
                    axi_bresp <= 2'b00; // OKAY
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 2. REGISTER MAP & W1C LOGIC
    // =========================================================================
    // Xung START (Bit 0) và SOFT RESET (Bit 1) từ CTRL_REG
    assign reg_start  = slv_reg_wren && (axi_awaddr[7:0] == ADDR_CTRL) && axi_wstrb_reg[0] && axi_wdata_reg[0];
    assign soft_reset = slv_reg_wren && (axi_awaddr[7:0] == ADDR_CTRL) && axi_wstrb_reg[0] && axi_wdata_reg[1];

    reg [15:0]  puf_chlg_reg;
    reg [31:0]  puf_wind_reg;
    reg [31:0]  aes_din_reg [0:3];
    reg [127:0] aes_dout_reg; 

    reg status_done_reg;
    reg status_error_reg;
    
    // Ngắt IRQ = 1 khi có DONE hoặc ERROR (Tính năng 2)
    assign irq = status_done_reg | status_error_reg;
    
    integer i;

    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            puf_chlg_reg     <= 16'hA5A5;
            puf_wind_reg     <= 32'd50;
            aes_din_reg[0]   <= 32'h0; aes_din_reg[1] <= 32'h0; 
            aes_din_reg[2]   <= 32'h0; aes_din_reg[3] <= 32'h0;
            status_done_reg  <= 1'b0;
            status_error_reg <= 1'b0;
            aes_dout_reg     <= 128'h0;
        end else begin
            // --- Hardware Update vs W1C Logic (Tính năng 4) ---
            if (reg_start) begin
                status_done_reg  <= 1'b0;
                status_error_reg <= 1'b0;
            end else begin
                // Cập nhật từ Hardware
                if (hw_error_pulse) status_error_reg <= 1'b1;
                else if (hw_done_pulse) begin
                    status_done_reg <= 1'b1;
                    aes_dout_reg    <= hw_aes_dout;
                end
                
                // Write-1-to-Clear từ CPU
                if (slv_reg_wren && axi_bresp == 2'b00 && axi_awaddr[7:0] == ADDR_STATUS) begin
                    if (axi_wstrb_reg[0]) begin
                        if (axi_wdata_reg[1]) status_done_reg  <= 1'b0; // CPU ghi 1 vào bit 1 để clear DONE
                        if (axi_wdata_reg[2]) status_error_reg <= 1'b0; // CPU ghi 1 vào bit 2 để clear ERROR
                    end
                end
            end

            // --- Cập nhật Data Registers ---
            if (slv_reg_wren && axi_bresp == 2'b00) begin
                case (axi_awaddr[7:0])
                    ADDR_PUF_CHLG: begin
                        if (axi_wstrb_reg[0]) puf_chlg_reg[7:0]  <= axi_wdata_reg[7:0];
                        if (axi_wstrb_reg[1]) puf_chlg_reg[15:8] <= axi_wdata_reg[15:8];
                    end
                    ADDR_PUF_WIND: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) puf_wind_reg[(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ADDR_AES_DIN0: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_din_reg[0][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ADDR_AES_DIN1: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_din_reg[1][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ADDR_AES_DIN2: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_din_reg[2][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
                    ADDR_AES_DIN3: for (i=0; i<4; i=i+1) if (axi_wstrb_reg[i]) aes_din_reg[3][(i*8)+:8] <= axi_wdata_reg[(i*8)+:8];
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
            axi_arready <= 1'b0;
            axi_araddr  <= 32'h0;
        end else if (ar_hs) begin
            axi_arready <= 1'b1;
            axi_araddr  <= s_axi_araddr;
        end else begin
            axi_arready <= 1'b0;
        end
    end

    wire slv_reg_rden = axi_arready && s_axi_arvalid && ~axi_rvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
            axi_rdata  <= 32'h0;
        end else begin
            if (slv_reg_rden) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; 
                
                case (axi_araddr[7:0])
                    ADDR_CTRL:      axi_rdata <= 32'h0;
                    ADDR_STATUS:    axi_rdata <= {29'h0, status_error_reg, status_done_reg, hw_busy}; 
                    ADDR_PUF_CHLG:  axi_rdata <= {16'h0, puf_chlg_reg}; 
                    ADDR_PUF_WIND:  axi_rdata <= puf_wind_reg;
                    ADDR_AES_DIN0:  axi_rdata <= aes_din_reg[0];
                    ADDR_AES_DIN1:  axi_rdata <= aes_din_reg[1];
                    ADDR_AES_DIN2:  axi_rdata <= aes_din_reg[2];
                    ADDR_AES_DIN3:  axi_rdata <= aes_din_reg[3];
                    ADDR_AES_DOUT0: axi_rdata <= aes_dout_reg[31:0];
                    ADDR_AES_DOUT1: axi_rdata <= aes_dout_reg[63:32];
                    ADDR_AES_DOUT2: axi_rdata <= aes_dout_reg[95:64];
                    ADDR_AES_DOUT3: axi_rdata <= aes_dout_reg[127:96];
                    ADDR_ID:        axi_rdata <= 32'h43525950; // "CRYP"
                    ADDR_VERSION:   axi_rdata <= 32'h00010000; // v1.0.0
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

    assign reg_puf_challenge = puf_chlg_reg;
    assign reg_puf_window    = puf_wind_reg;
    assign reg_aes_din       = {aes_din_reg[3], aes_din_reg[2], aes_din_reg[1], aes_din_reg[0]};

endmodule