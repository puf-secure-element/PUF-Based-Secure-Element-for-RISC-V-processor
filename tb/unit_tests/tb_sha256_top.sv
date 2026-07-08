`timescale 1ns/1ps

module tb_sha256_top;

reg         clk;
reg         rst_n;

reg         sel;
reg         we;
reg [7:0]   addr;
reg [31:0]  wdata;

wire [31:0] rdata;
wire        error;

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
    .rdata(rdata),
    .error(error)
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

    clk   = 0;
    rst_n = 0;

    sel   = 0;
    we    = 0;
    addr  = 0;
    wdata = 0;

    repeat(5) @(posedge clk);
    rst_n = 1;

    write_reg(8'h10,32'h61626380);
    write_reg(8'h11,32'h00000000);
    write_reg(8'h12,32'h00000000);
    write_reg(8'h13,32'h00000000);
    write_reg(8'h14,32'h00000000);
    write_reg(8'h15,32'h00000000);
    write_reg(8'h16,32'h00000000);
    write_reg(8'h17,32'h00000000);
    write_reg(8'h18,32'h00000000);
    write_reg(8'h19,32'h00000000);
    write_reg(8'h1A,32'h00000000);
    write_reg(8'h1B,32'h00000000);
    write_reg(8'h1C,32'h00000000);
    write_reg(8'h1D,32'h00000000);
    write_reg(8'h1E,32'h00000000);
    write_reg(8'h1F,32'h00000018);


    $display("START SHA256");

    write_reg(8'h00,32'h00000001);

    @(posedge dut.hash_valid);

    $display("HASH VALID!");

    $display("\n===== Start Reading ADDR_CRTL Register =====");
    read_reg(8'h00);
    $display("\n===== Start Reading ADDR_STATUS Register =====");
    read_reg(8'h04);
    $display("\n===== Start Reading ADDR_BLOCK Register =====");
    for(i=0;i<8;i=i+1)
        read_reg(8'h20+i);
    $display("\n===== Start Reading ADDR_HASH Register =====");
    for(i=0;i<8;i=i+1)
        read_reg(8'h10+i);

    $display("\n===== Start new Test =====");
    write_reg(8'h10,32'h68656c6c); 
    write_reg(8'h11,32'h6f800000); 
    write_reg(8'h12,32'h00000000);
    write_reg(8'h13,32'h00000000);
    write_reg(8'h14,32'h00000000);
    write_reg(8'h15,32'h00000000);
    write_reg(8'h16,32'h00000000);
    write_reg(8'h17,32'h00000000);
    write_reg(8'h18,32'h00000000);
    write_reg(8'h19,32'h00000000);
    write_reg(8'h1A,32'h00000000);
    write_reg(8'h1B,32'h00000000);
    write_reg(8'h1C,32'h00000000);
    write_reg(8'h1D,32'h00000000);
    write_reg(8'h1E,32'h00000000);
    write_reg(8'h1F,32'h00000028); 


    $display("START SHA256");

    write_reg(8'h00,32'h00000001);
    @(posedge dut.hash_valid);

    $display("HASH VALID!");

    $display("\n===== Start Reading ADDR_CRTL Register =====");
    read_reg(8'h00);
    $display("\n===== Start Reading ADDR_STATUS Register =====");
    read_reg(8'h04);
    $display("\n===== Start Reading ADDR_BLOCK Register =====");
    for(i=0;i<8;i=i+1)
        read_reg(8'h20+i);
    $display("\n===== Start Reading ADDR_HASH Register =====");
    for(i=0;i<8;i=i+1)
        read_reg(8'h10+i);

    #200;
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
            dut.hash_valid, dut.sha256_core.round_cnt_reg, dut.hash_out);
end

endmodule