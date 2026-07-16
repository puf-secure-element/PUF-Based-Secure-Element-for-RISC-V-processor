`timescale 1ns / 1ps

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
    output wire [127:0] data_out    // Thêm port xuất dữ liệu ra ngoài
);

    // Wires nội bộ
    wire reg_start, soft_reset;
    wire hw_busy, hw_done_pulse, hw_error_pulse;
    wire [15:0]  reg_puf_challenge;
    wire [31:0]  reg_puf_window;
    wire [127:0] reg_aes_din;
    wire [127:0] hw_aes_dout;
    
    wire puf_start, ecc_start, sha_start, aes_start;
    wire puf_valid, ecc_valid, sha_valid, sha_error, aes_done;

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
        .reg_aes_din        (reg_aes_din),
        .hw_aes_dout        (hw_aes_dout)
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
        .aes_done           (aes_done)
    );

    axi_slave_core u_core (
        .clk                (clk),
        .rst_n              (rst_n),
        .puf_challenge      (reg_puf_challenge),
        .puf_window         (reg_puf_window),
        .aes_din            (reg_aes_din),
        .puf_start          (puf_start),
        .puf_valid          (puf_valid),
        .ecc_start          (ecc_start),
        .ecc_valid          (ecc_valid),
        .sha_start          (sha_start),
        .sha_valid          (sha_valid),
        .sha_error          (sha_error),
        .aes_start          (aes_start),
        .aes_done           (aes_done),
        .aes_dout           (hw_aes_dout)
    );

    // Kéo thẳng tín hiệu data từ lõi AES ra ngoài port
    assign data_out = hw_aes_dout;

endmodule