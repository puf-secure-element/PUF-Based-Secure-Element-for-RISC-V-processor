module tb_soc;

    reg clk;
    reg rst_n;

    wire [127:0] data_out;
    wire         done;

    soc dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_out(data_out),
        .irq(done)
    );

    //------------------------------------------------------
    // Clock
    //------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //------------------------------------------------------
    // Header
    //------------------------------------------------------
    initial begin
        $display("==============================================================");
        $display("                SoC Simulation Start");
        $display("==============================================================");
    end

    //------------------------------------------------------
    // Monitor: Print only when signal changes
    //------------------------------------------------------
    reg [511:0] last_puf;
    reg [511:0] last_ecc;
    reg [255:0] last_key;
    reg [255:0] last_aes;

    initial begin
        last_puf = 'x;
        last_ecc = 'x;
        last_key = 'x;
        last_aes = 'x;
    end

    always @(dut.puf_valid)
        $display("[%0t] puf_valid = %b", $time, dut.puf_valid);

    always @(dut.ecc_valid)
        $display("[%0t] ecc_valid = %b", $time, dut.ecc_valid);

    always @(dut.key_is_ready)
        $display("[%0t] key_ready = %b", $time, dut.key_is_ready);

    always @(dut.irq)
        $display("[%0t] aes_done = %b", $time, dut.irq);

    always @(dut.puf_response or
             dut.ecc_response or
             dut.key or
             dut.data_out)
    begin

        if (dut.puf_response !== last_puf) begin
            last_puf = dut.puf_response;
            $display("[%0t] PUF Response", $time);
            $display("%0512h", dut.puf_response);
            $display("--------------------------------------------------------------");
        end

        if (dut.ecc_response !== last_ecc) begin
            last_ecc = dut.ecc_response;
            $display("[%0t] ECC Response", $time);
            $display("%0512h", dut.ecc_response);
            $display("--------------------------------------------------------------");
        end

        if (dut.key !== last_key) begin
            last_key = dut.key;
            $display("[%0t] SHA256 Key", $time);
            $display("%0256h", dut.key);
            $display("--------------------------------------------------------------");
        end

        if (dut.data_out !== last_aes) begin
            last_aes = dut.data_out;
            $display("[%0t] AES Output", $time);
            $display("%0256h", dut.data_out);
            $display("--------------------------------------------------------------");
        end

    end


    // always @(dut.key_is_ready)
    //     $display("[%0t] key_is_ready = %b", $time, dut.key_is_ready);

    // always @(dut.done)
    //     $display("[%0t] aes_done = %b", $time, dut.done);

     always @(dut.data_out) begin
        $display("round=%0d key_index=%0d active=%0b done=%0b data=%h",
                dut.dut.round,
                dut.dut.key_index,
                dut.dut.active,
                dut.irq,
                dut.data_out);
     end



    //------------------------------------------------------
    // Write task
    //------------------------------------------------------
    reg [31:0] tb_addr;
    reg [31:0] tb_data;

// reg [7:0]   last_sha_addr;
// reg [31:0]  last_sha_wdata;
// reg [511:0] last_sha_ecc;
// reg [255:0] last_sha_key;
// reg         last_sha_valid;

// initial begin
//     last_sha_addr  = 'x;
//     last_sha_wdata = 'x;
//     last_sha_ecc   = 'x;
//     last_sha_key   = 'x;
//     last_sha_valid = 'x;
// end

// always @(dut.address or
//          dut.cpu_wdata or
//          dut.ecc_response or
//          dut.key or
//          dut.key_is_ready)
// begin

//     if (dut.address !== last_sha_addr ||
//         dut.cpu_wdata !== last_sha_wdata ||
//         dut.ecc_response !== last_sha_ecc ||
//         dut.key !== last_sha_key ||
//         dut.key_is_ready !== last_sha_valid) begin

//         $display("\n==============================================================");
//         $display("[SHA CHANGE @ %0t]", $time);

//         $display("  address       = %h",     dut.address);
//         $display("  wdata         = %08h",   dut.cpu_wdata);

//         $display("  ecc_response  = %0512h", dut.ecc_response);
//         $display("  ecc_valid     = %b",     dut.ecc_valid);

//         $display("  rdata         = %08h",   dut.cpu_rdata);
//         $display("  error         = %b",     dut.sha_error);

//         $display("  hash_out/key  = %0256h", dut.key);
//         $display("  hash_valid    = %b",     dut.key_is_ready);

//         $display("==============================================================");

//         last_sha_addr  = dut.address;
//         last_sha_wdata = dut.cpu_wdata;
//         last_sha_ecc   = dut.ecc_response;
//         last_sha_key   = dut.key;
//         last_sha_valid = dut.key_is_ready;
//     end
// end

// always @(posedge clk) begin
//     $display(
//         "[%0t] req=%b we=%b addr=%h wdata=%h ready=%b",
//         $time,
//         dut.cpu_req,
//         dut.cpu_we,
//         dut.cpu_addr,
//         dut.cpu_wdata,
//         dut.cpu_ready
//     );
// end

    task write_reg(input [31:0] addr, input [31:0] data);
    begin
        tb_addr = addr;
        tb_data = data;
        @(posedge clk);
    end
    endtask

    //------------------------------------------------------
    // Test Sequence
    //------------------------------------------------------
    initial begin

        rst_n = 0;
        tb_addr = 0;
        tb_data = 0;

        #30;
        rst_n = 1;

        repeat(2) @(posedge clk);

        // // AES control = Encrypt
        // write_reg(32'h08, 32'h2);

        // // ECC mode = Enrollment
        // write_reg(32'h0C, 32'h0);

        // // SHA start
        // write_reg(32'h00, 32'h1);

        // // PUF start
        // write_reg(32'h10, 32'h1);

        // Wait for system
        repeat(1000) @(posedge clk);

        $display("\n========== Simulation Finished ==========");
        $finish;
    end

endmodule
