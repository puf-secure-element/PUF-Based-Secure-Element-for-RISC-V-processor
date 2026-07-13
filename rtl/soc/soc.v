module soc(
    input   wire            clk,
    input   wire            rst_n,

    output  wire    [127:0] data_out,
    output  wire            done
);

    parameter   SHA_ADDR_CTRL       = 8'h00;
    parameter   SHA_ADDR_STATUS     = 8'h04;
    // //Hash addresses
    // parameter   SHA_ADDR_HASH0      = 8'h20;
    // parameter   SHA_ADDR_HASH7      = 8'h27;

    parameter   AES_ADDR_CTRL       = 8'h08;    //Bit 0 to control decryption, bit 1 to control encryption

    parameter   ECC_ADDR_CTRL       = 8'hC;     //Bit 0 to control mode, 0: Enrollment, 1: Reconstruction

    parameter   PUF_ADDR_CTRL       = 8'h10;    //Control PUF, write 1 to bit 0 to start transfer challenges

    wire            key_is_ready, ecc_valid;
    wire    [7:0]   address;                    //Address written to control modules

    //AES internal signals
    wire            de, en;

    //SHA internal signals
    wire            sha_error;
    wire    [255:0] key;

    //RV32 internal signals
    wire            error_flag;
    wire    [31:0]  rv_address;
    wire    [31:0]  rv_rdata;
    wire    [31:0]  rv_wdata;

    //ECC internal signals
    wire            mode;
    wire    [511:0] ecc_response;

    //PUF internal signals
    wire            puf_valid;
    wire            start_puf;
    wire    [511:0] puf_response;


    assign  address     =   rv_address[7:0];
    //AES
    assign  de          =   ((address == AES_ADDR_CTRL) && (rv_wdata[0] == 1)) ? 1'b1 : 1'b0;  //wdata[0] = 0
    assign  en          =   ((address == AES_ADDR_CTRL) && (rv_wdata[1] == 1)) ? 1'b1 : 1'b0;  //wdata[1] = 1
    //ECC
    assign  mode        =   ((address == ECC_ADDR_CTRL) && rv_wdata[0]);  //wdata[0] = 1
    //PUF
    assign  start_puf   =   ((address == PUF_ADDR_CTRL) && (rv_wdata[0] == 1)) ? 1'b1 : 1'b0;  //wdata[1] = 1

    aes dut(
        .clk(clk),
        .rst_n(rst_n),

        .decrypt(de),
        .encrypt(en),

        .plaintext(128'hD4A71F92_8C3EB650_19F8A2CD_7B45E10F),       //4 Instructions delay 4 clk to create 128 bits plaintext

        .key_is_ready(key_is_ready),
        .key_in(key),
        //Encrypt/Decrypt value
        .data_out(data_out),
        .done(done)
    );

    sha256_top sha256(
        .clk(clk),
        .rst_n(rst_n),

        .sel(1'b1),
        .we(1'b1),

        .addr(address),
        .wdata(rv_wdata),

        .ecc_response(ecc_response),
        .ecc_valid(ecc_valid),

        .rdata(rv_rdata),
        .error(sha_error),
        .hash_out(key),
        .hash_valid(key_is_ready)
    );

    RV32I rv32(
        .clk(clk),
        .rst_n(rst_n)
    );

    ecc_top ecc(
        .clk_i(clk),
        .rst_n_i(rst_n),
        .mode_i(mode),
        .start_i(puf_valid),
        .raw_resp_i(puf_response),
        .helper_in_i(),
        .helper_val_i(),

        .helper_out_o(),
        .corr_resp_o(ecc_response),
        .corr_resp_val_o(ecc_valid)
    );

    ro_puf_core puf(
        .clk(clk),
        .rst_n(rst_n),

        .start(start_puf),
        .measure_window(32'd50),
        .challenge(16'hA5A5),

        .response(puf_response),
        .response_ready(puf_valid),
        .core_busy()
    );


endmodule