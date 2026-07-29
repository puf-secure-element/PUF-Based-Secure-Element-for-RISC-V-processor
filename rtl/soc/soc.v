module soc (
    input   wire            clk,
    input   wire            rst_n,

    // Giao diện quan sát cho Testbench
    output  wire    [127:0] data_out,
    output  wire            irq
);

    parameter   SHA_ADDR_CTRL       = 8'h00;
    parameter   SHA_ADDR_STATUS     = 8'h04;
    // //Hash addresses
    // parameter   SHA_ADDR_HASH0      = 8'h20;
    // parameter   SHA_ADDR_HASH7      = 8'h27;
    parameter   AES_ADDR_CTRL       = 8'h08;    //Bit 0 to control decryption, bit 1 to control encryption
    parameter   ECC_ADDR_CTRL       = 8'hC;     //Bit 0 to control mode, 0: Enrollment, 1: Reconstruction
    parameter   PUF_ADDR_CTRL       = 8'h10;    //Control PUF, write 1 to bit 0 to start transfer challenges

    // =========================================================================
    // DÂY BUS AXI4-LITE NỘI BỘ
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

    wire            key_is_ready, ecc_valid;
    wire    [7:0]   address;                    //Address written to control modules

    //AES internal signals
    wire            de, en;

    //SHA internal signals
    wire            sha_error;
    wire    [255:0] key;

    //ECC internal signals
    wire            mode;
    wire    [511:0] ecc_response;

    //PUF internal signals
    wire            puf_valid;
    wire            start_puf;
    wire    [511:0] puf_response;


    assign  address     =   cpu_addr[7:0];
    //AES
    assign  de          =   ((address == AES_ADDR_CTRL) && (cpu_wdata[0] == 1)) ? 1'b1 : 1'b0;  //wdata[0] = 0
    assign  en          =   ((address == AES_ADDR_CTRL) && (cpu_wdata[1] == 1)) ? 1'b1 : 1'b0;  //wdata[1] = 1
    //ECC
    assign  mode        =   ((address == ECC_ADDR_CTRL) && cpu_wdata[0]);  //wdata[0] = 1
    //PUF
    assign  start_puf   =   ((address == PUF_ADDR_CTRL) && (cpu_wdata[0] == 1)) ? 1'b1 : 1'b0;  //wdata[1] = 1

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
        .s_axi_awvalid  (axi_awvalid),
        .s_axi_awready  (axi_awready),
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wvalid   (axi_wvalid),
        .s_axi_wready   (axi_wready),
        .s_axi_bresp    (axi_bresp),
        .s_axi_bvalid   (axi_bvalid),
        .s_axi_bready   (axi_bready),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arvalid  (axi_arvalid),
        .s_axi_arready  (axi_arready),
        .s_axi_rdata    (axi_rdata),
        .s_axi_rresp    (axi_rresp),
        .s_axi_rvalid   (axi_rvalid),
        .s_axi_rready   (axi_rready),
        
        // Cắm dây xuất ra SoC ngoài cùng
        .irq            (irq),
        .data_out       (data_out)
    );

     aes dut(
        .clk            (clk),
        .rst_n          (rst_n),

        .decrypt        (de),
        .encrypt        (en),

        .plaintext      (128'hD4A71F92_8C3EB650_19F8A2CD_7B45E10F),       //4 Instructions delay 4 clk to create 128 bits plaintext

        .key_is_ready   (key_is_ready),
        .key_in         (key),
        //Encrypt/Decrypt value
        .data_out       (data_out),
        .done           (done)
    );

    sha256_top sha256(
        .clk            (clk),
        .rst_n          (rst_n),

        .sel            (1'b1),
        .we             (1'b1),

        .addr           (address),
        .wdata          (cpu_wdata),

        .ecc_response   (ecc_response),
        .ecc_valid      (ecc_valid),

        .rdata          (cpu_rdata),
        .error          (sha_error),
        .hash_out       (key),
        .hash_valid     (key_is_ready)
    );

    ecc_top ecc(
        .clk_i          (clk),
        .rst_n_i        (rst_n),
        .mode_i         (mode),
        .start_i        (puf_valid),
        .raw_resp_i     (puf_response),
        .helper_in_i    (),
        .helper_val_i   (),

        .helper_out_o   (),
        .corr_resp_o    (ecc_response),
        .corr_resp_val_o(ecc_valid)
    );

    ro_puf_core puf(
        .clk            (clk),
        .rst_n          (rst_n),

        .start          (start_puf),
        .measure_window (32'd50),
        .challenge      (16'hA5A5),

        .response       (puf_response),
        .response_ready (puf_valid),
        .core_busy      ()
    );



endmodule