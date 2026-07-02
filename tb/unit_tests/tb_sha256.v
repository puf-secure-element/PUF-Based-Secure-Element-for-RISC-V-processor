`timescale 1ns/1ps

module tb_sha256;

reg         clk;
reg         rst_n;
reg         start;
reg         next;
reg [511:0] data_in;

wire [255:0] hash_out;
wire         hash_valid;
wire         done;

//----------------------------------------------------
// DUT
//----------------------------------------------------
sha256 dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .next(next),
    .data_in(data_in),

    .hash_out(hash_out),
    .hash_valid(hash_valid),
    .done(done)
);


//----------------------------------------------------
// Clock
//----------------------------------------------------
always #5 clk = ~clk;


//----------------------------------------------------
// Display hash
//----------------------------------------------------
always @(posedge clk) begin
    //if(hash_valid) begin
        $display("--------------------------------------------");
        $display("Time = %0t", $time);
        $display("HASH = %064h", hash_out);
        $display("--------------------------------------------");
    //end
end


//----------------------------------------------------
// Test
//----------------------------------------------------
initial begin

    clk     = 0;
    rst_n   = 0;
    start   = 0;
    next    = 0;
    data_in = 512'd0;

    //------------------------------------------------
    // Reset
    //------------------------------------------------
    #30;
    rst_n = 1;

    #20;

    data_in = {
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

    @(posedge clk);
    start <= 1;

    @(posedge clk);
    start <= 0;

    wait(hash_valid);

    #50;

    wait(done);

    data_in = 512'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;

    @(posedge clk);
    next <= 1;

    @(posedge clk);
    next <= 0;

    wait(hash_valid);

    #100;

    $finish;

end


//----------------------------------------------------
// Monitor
//----------------------------------------------------
always @(posedge clk) begin

    $display("T=%0t state=%0d round=%0d start=%b next=%b done=%b hash_valid=%b",
             $time,
             dut.state_reg,
             dut.round_cnt_reg,
             start,
             next,
             done,
             hash_valid);

end

endmodule
