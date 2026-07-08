`timescale 1ns/1ps

module tb_sha256_top;

reg         clk;
reg         rst_n;

reg         sel;
reg         we;
reg [7:0]   addr;
reg [31:0]  wdata;

reg  [511:0] ecc_response;
reg          ecc_valid;

wire [31:0] rdata;
wire        error;
wire [255:0] hash_out;
wire         hash_valid;

integer i;

//------------------------------------------------
// DUT
//------------------------------------------------
sha256_top dut (
    .clk(clk),
    .rst_n(rst_n),

    .sel(sel),
    .we(we),
    .addr(addr),
    .wdata(wdata),

    .ecc_response(ecc_response),
    .ecc_valid(ecc_valid),

    .rdata(rdata),
    .error(error),

    .hash_out(hash_out),
    .hash_valid(hash_valid)
);

//------------------------------------------------
// Clock
//------------------------------------------------
always #5 clk = ~clk;

//------------------------------------------------
// Bus Write
//------------------------------------------------
task write_reg;
input [7:0] address;
input [31:0] data;
begin
    @(posedge clk);
    sel   <= 1;
    we    <= 1;
    addr  <= address;
    wdata <= data;

    @(posedge clk);
    sel   <= 0;
    we    <= 0;
    addr  <= 0;
    wdata <= 0;
end
endtask

//------------------------------------------------
// Bus Read
//------------------------------------------------
task read_reg;
input [7:0] address;
begin
    @(posedge clk);
    sel  <= 1;
    we   <= 0;
    addr <= address;

    @(posedge clk);
    $display("[%0t] READ Addr=%h Data=%h",
             $time, address, rdata);

    sel  <= 0;
    addr <= 0;
end
endtask

//------------------------------------------------
// Test
//------------------------------------------------
initial begin

    clk          = 0;
    rst_n        = 0;

    sel          = 0;
    we           = 0;
    addr         = 0;
    wdata        = 0;

    ecc_response = 512'd0;
    ecc_valid    = 0;

    repeat(5) @(posedge clk);
    rst_n = 1;

    //------------------------------------------------
    // TEST 1 : "abc"
    //------------------------------------------------

    ecc_response = {
        32'h61626380,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000018
    };

    ecc_valid = 1;

    $display("\n==============================");
    $display("START SHA256 : abc");
    $display("==============================");

    write_reg(8'h00,32'h00000001);

    @(posedge hash_valid);

    ecc_valid = 0;

    $display("HASH VALID!");

    read_reg(8'h00);
    read_reg(8'h04);

    for(i=0;i<8;i=i+1)
        read_reg(8'h20+i);

    //------------------------------------------------
    // TEST 2 : "abc"
    //------------------------------------------------

    ecc_response = {
        32'h61626380,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000018
    };

    ecc_valid = 1;

    $display("\n==============================");
    $display("START SHA256 : Keep OLD Data in");
    $display("==============================");

    write_reg(8'h00,32'h1);

    repeat(20) @(posedge clk);

    //------------------------------------------------
    // TEST 3 : "hello"
    //------------------------------------------------

    ecc_response = {
        32'h68656c6c,
        32'h6f800000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000000,
        32'h00000028
    };

    ecc_valid = 1;

    $display("\n==============================");
    $display("START SHA256 : hello");
    $display("==============================");

    write_reg(8'h00,32'h00000001);

    @(posedge hash_valid);

    ecc_valid = 0;

    $display("HASH VALID!");

    read_reg(8'h00);
    read_reg(8'h04);

    for(i=0;i<8;i=i+1)
        read_reg(8'h20+i);

    #100;
    $finish;

end

//------------------------------------------------
// Monitor
//------------------------------------------------
always @(posedge clk) begin 
    $display("T=%0t start=%b next=%b done=%b hash_valid=%b count=%0d hash_out=%h", 
            $time, 
            dut.start_reg, 
            dut.next_reg, 
            dut.done, 
            dut.hash_valid, 
            dut.sha256_core.round_cnt_reg, 
            dut.hash_out); 
end

endmodule