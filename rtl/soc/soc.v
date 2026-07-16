`timescale 1ns / 1ps

module soc (
    input   wire            clk,
    input   wire            rst_n,

    // Giao diện quan sát cho Testbench
    output  wire    [127:0] data_out,
    output  wire            irq
);

    // =========================================================================
    // DÂY BUS AXI4-LITE NỘI BỘ
    // =========================================================================
    wire [31:0] axi_awaddr;
    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    wire        axi_wvalid;
    wire        axi_wready;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;
    wire [31:0] axi_araddr;
    wire        axi_arvalid;
    wire        axi_arready;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rvalid;
    wire        axi_rready;

    // =========================================================================
    // TÍN HIỆU GIAO TIẾP NATIVE CPU
    // =========================================================================
    wire        cpu_req;
    wire        cpu_we;
    wire [31:0] cpu_addr;
    wire [31:0] cpu_wdata;
    wire [3:0]  cpu_wstrb;
    wire [31:0] cpu_rdata;
    wire        cpu_ready;
    wire        cpu_error;

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

endmodule