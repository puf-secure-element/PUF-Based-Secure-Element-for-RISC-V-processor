module soc (
    input   wire            clk,
    input   wire            rst_n,

    // Giao diện quan sát cho Testbench
    output  wire    [127:0] data_out,
    output  wire            irq,

    // UART serial pins
    input   wire             uart_rxd,
    output  wire             uart_txd,
    output  wire             uart_irq
);

    parameter   SHA_ADDR_CTRL       = 10'h00;
    parameter   SHA_ADDR_STATUS     = 10'h04;
    // //Hash addresses
    // parameter   SHA_ADDR_HASH0      = 10'h20;
    // parameter   SHA_ADDR_HASH7      = 10'h27;
    parameter   AES_ADDR_CTRL       = 10'h08;    //Bit 0 to control decryption, bit 1 to control encryption
    parameter   ECC_ADDR_CTRL       = 10'h0C;     //Bit 0 to control mode, 0: Enrollment, 1: Reconstruction
    parameter   PUF_ADDR_CTRL       = 10'h10;    //Control PUF, write 1 to bit 0 to start transfer challenges

    // =========================================================================
    // DÂY BUS AXI4-LITE NỘI BỘ (từ CPU)
    // =========================================================================
    wire    [31:0]  axi_awaddr;
    wire            axi_awvalid;
    wire            axi_awready;
    wire    [31:0]  axi_wdata;
    wire    [3:0]   axi_wstrb;
    wire            axi_wvalid;
    wire            axi_wready;
    wire    [1:0]   axi_bresp;
    wire            axi_bvalid;
    wire            axi_bready;
    wire    [31:0]  axi_araddr;
    wire            axi_arvalid;
    wire            axi_arready;
    wire    [31:0]  axi_rdata;
    wire    [1:0]   axi_rresp;
    wire            axi_rvalid;
    wire            axi_rready;

    // =========================================================================
    // ADDRESS MAP (1 AXI master -> 2 AXI slaves)
    //   0x0000_0000 - 0x0000_0FFF : crypto accelerator (axi_slave_top)
    //   0x0000_1000 - 0x0000_13FF : UART config regs, via axi2ahb_bridge
    //                               (bridge forwards addr[9:0] as HADDR)
    // Selection uses bit 12 - safe since axi_reg_bank only decodes addr[7:0]
    // (max 0xFC) and uart_top's HADDR is only 10 bits (max 0x3FF), both well
    // under the 4KB-per-peripheral spacing below.
    // =========================================================================
    wire sel_uart_aw = axi_awaddr[12];
    wire sel_uart_ar = axi_araddr[12];

    // Crypto slave port
    wire            crypto_awvalid = axi_awvalid & ~sel_uart_aw;
    wire            crypto_wvalid  = axi_wvalid  & ~sel_uart_aw;
    wire            crypto_arvalid = axi_arvalid & ~sel_uart_ar;
    wire            crypto_awready, crypto_wready, crypto_arready;
    wire            crypto_bvalid, crypto_rvalid;
    wire [1:0]      crypto_bresp, crypto_rresp;
    wire [31:0]     crypto_rdata;

    // UART bridge slave port
    wire            uart_awvalid = axi_awvalid & sel_uart_aw;
    wire            uart_wvalid  = axi_wvalid  & sel_uart_aw;
    wire            uart_arvalid = axi_arvalid & sel_uart_ar;
    wire            uart_awready, uart_wready, uart_arready;
    wire            uart_bvalid, uart_rvalid;
    wire [1:0]      uart_bresp, uart_rresp;
    wire [31:0]     uart_rdata;

    // Response/ready muxing back to the CPU master. Safe as an OR-mux
    // because only one slave is ever selected per transaction and
    // rv32_axi_master never has more than one transaction outstanding.
    assign axi_awready = sel_uart_aw ? uart_awready : crypto_awready;
    assign axi_wready  = sel_uart_aw ? uart_wready  : crypto_wready;
    assign axi_bvalid  = crypto_bvalid | uart_bvalid;
    assign axi_bresp   = crypto_bvalid ? crypto_bresp : uart_bresp;

    assign axi_arready = sel_uart_ar ? uart_arready : crypto_arready;
    assign axi_rvalid  = crypto_rvalid | uart_rvalid;
    assign axi_rdata   = crypto_rvalid ? crypto_rdata : uart_rdata;
    assign axi_rresp   = crypto_rvalid ? crypto_rresp : uart_rresp;

    // AHB-Lite master port driven by the bridge, into uart_top
    wire [9:0]  ahb_HADDR;
    wire [1:0]  ahb_HTRANS;
    wire [2:0]  ahb_HBURST;
    wire [2:0]  ahb_HSIZE;
    wire [3:0]  ahb_HPROT;
    wire        ahb_HWRITE;
    wire        ahb_HSEL;
    wire [31:0] ahb_HWDATA;
    wire        ahb_HREADYOUT;
    wire [31:0] ahb_HRDATA;
    wire        ahb_HRESP;

    // =========================================================================
    // TÍN HIỆU GIAO TIẾP NATIVE CPU
    // =========================================================================
    wire            cpu_req;
    wire            cpu_we;
    wire    [31:0]  cpu_addr;
    wire    [31:0]  cpu_wdata;
    wire    [3:0]   cpu_wstrb;
    wire    [31:0]  cpu_rdata;
    wire            cpu_ready;
    wire            cpu_error;

    // UART <-> AES streaming bridge
    wire    [127:0] w_uart_plaintext;
    wire            w_uart_plaintext_valid;
    wire    w_uart_enroll_valid;
    wire    w_aes_block_valid;
    wire    w_enroll_block_valid;
    wire    [95:0] w_enroll_helper;
    wire    [255:0] w_enroll_key;

    // =========================================================================
    // 1. KHỐI CPU RISC-V (Bản đã nâng cấp có mem_req, mem_ready)
    // =========================================================================
    RV32I rv32 (
        .clk        (clk),
        .rst_n      (rst_n),
        
        .mem_req    (cpu_req),    
        .mem_we     (cpu_we),     
        .mem_addr   (cpu_addr),   
        .mem_wdata  (cpu_wdata),  
        .mem_wstrb  (cpu_wstrb),  
        
        .mem_rdata  (cpu_rdata),  
        .mem_ready  (cpu_ready),  
        .mem_error  (cpu_error)   
    );

    // =========================================================================
    // 2. KHỐI AXI MASTER WRAPPER
    // =========================================================================
    rv32_axi_master axi_master_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        
        .cpu_req        (cpu_req),
        .cpu_we         (cpu_we),
        .cpu_addr       (cpu_addr),
        .cpu_wdata      (cpu_wdata),
        .cpu_wstrb      (cpu_wstrb),
        .cpu_rdata      (cpu_rdata),
        .cpu_ready      (cpu_ready),
        .cpu_error      (cpu_error),
        
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready)
    );

    // =========================================================================
    // 3. KHỐI AXI SLAVE SUBSYSTEM (Chứa Crypto IPs)
    // =========================================================================
    axi_slave_top crypto_accelerator (
        .clk            (clk),
        .rst_n          (rst_n),
        
        .s_axi_awaddr   (axi_awaddr),
        .s_axi_awvalid  (crypto_awvalid),
        .s_axi_awready  (crypto_awready),
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wvalid   (crypto_wvalid),
        .s_axi_wready   (crypto_wready),
        .s_axi_bresp    (crypto_bresp),
        .s_axi_bvalid   (crypto_bvalid),
        .s_axi_bready   (axi_bready),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arvalid  (crypto_arvalid),
        .s_axi_arready  (crypto_arready),
        .s_axi_rdata    (crypto_rdata),
        .s_axi_rresp    (crypto_rresp),
        .s_axi_rvalid   (crypto_rvalid),
        .s_axi_rready   (axi_rready),
        
        // Cắm dây xuất ra SoC ngoài cùng
        .irq            (irq),
        .data_out       (data_out),

        .uart_plaintext         (w_uart_plaintext),
        .uart_plaintext_valid   (w_uart_plaintext_valid),
        .uart_enroll_valid      (w_uart_enroll_valid),
        .aes_block_valid        (w_aes_block_valid)
        ,.enroll_block_valid    (w_enroll_block_valid)
        ,.enroll_helper         (w_enroll_helper)
        ,.enroll_key            (w_enroll_key)
    );

    // =========================================================================
    // 3b. AXI4-Lite -> AHB-Lite BRIDGE (CPU reaches UART config registers)
    // =========================================================================
    axi_to_ahb u_axi2ahb (
        .clk            (clk),
        .rst_n          (rst_n),

        .s_axi_awaddr   (axi_awaddr),
        .s_axi_awvalid  (uart_awvalid),
        .s_axi_awready  (uart_awready),
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wvalid   (uart_wvalid),
        .s_axi_wready   (uart_wready),
        .s_axi_bresp    (uart_bresp),
        .s_axi_bvalid   (uart_bvalid),
        .s_axi_bready   (axi_bready),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arvalid  (uart_arvalid),
        .s_axi_arready  (uart_arready),
        .s_axi_rdata    (uart_rdata),
        .s_axi_rresp    (uart_rresp),
        .s_axi_rvalid   (uart_rvalid),
        .s_axi_rready   (axi_rready),

        .m_HADDR        (ahb_HADDR),
        .m_HTRANS       (ahb_HTRANS),
        .m_HBURST       (ahb_HBURST),
        .m_HSIZE        (ahb_HSIZE),
        .m_HPROT        (ahb_HPROT),
        .m_HWRITE       (ahb_HWRITE),
        .m_HSEL         (ahb_HSEL),
        .m_HWDATA       (ahb_HWDATA),
        .m_HREADYOUT    (ahb_HREADYOUT),
        .m_HRDATA       (ahb_HRDATA),
        .m_HRESP        (ahb_HRESP)
    );

    // =========================================================================
    // 4. UART (RX plaintext -> AES, AES data_out -> TX, CPU config via AHB)
    // =========================================================================
    uart_top u_uart (
        .HCLK           (clk),
        .HRESETN        (rst_n),
        .HADDR          (ahb_HADDR),
        .HTRANS         (ahb_HTRANS),
        .HBURST         (ahb_HBURST),
        .HSIZE          (ahb_HSIZE),
        .HPROT          (ahb_HPROT),
        .HWRITE         (ahb_HWRITE),
        .HSEL           (ahb_HSEL),
        .HWDATA         (ahb_HWDATA),
        .HREADYOUT      (ahb_HREADYOUT),
        .HRDATA         (ahb_HRDATA),
        .HRESP          (ahb_HRESP),

        .uart_rxd       (uart_rxd),
        .uart_txd       (uart_txd),
        .interrupt      (uart_irq),

        .plaintext_valid    (w_uart_plaintext_valid),
        .plaintext          (w_uart_plaintext),
        .enroll_valid       (w_uart_enroll_valid),

        .aes_block_valid    (w_aes_block_valid),
        .aes_data_out       (data_out),
        .enroll_block_valid (w_enroll_block_valid),
        .enroll_helper      (w_enroll_helper),
        .enroll_key         (w_enroll_key)
    );

endmodule