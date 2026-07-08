`timescale 1ns/1ps

module tb_key_expansion;

    reg         key_is_ready;
    reg [255:0] key;

    wire [1919:0] dut_t;
    wire [1919:0] dut_f;

    wire [1919:0] golden;

    integer i;
    integer err;

    //------------------------------------------------------
    // DUT
    //------------------------------------------------------

    key_expansion dut (
        .key_is_ready (key_is_ready),
        .key_in       (key),
        .w_out_t      (dut_t),
        .w_out_f      (dut_f)
    );

    //------------------------------------------------------
    // Golden model
    //------------------------------------------------------

    key_expansion_golden #(
        .nk(8),
        .nr(14)
    ) golden_model (
        .key(key),
        .w(golden)
    );

    //------------------------------------------------------
    // Test
    //------------------------------------------------------

    initial begin

        key_is_ready = 0;
        key = 0;

        #20;

        //--------------------------------------------------
        // AES-256 NIST Example Key
        //--------------------------------------------------

        key =
        256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;

        key_is_ready = 1;

        #20;

        err = 0;

        $display("---------------------------------------------");
        $display("Comparing Expanded Keys");
        $display("---------------------------------------------");

        for(i=0;i<60;i=i+1) begin

            if(dut_t[i*32 +:32] !== golden[(59-i)*32 +:32]) begin

                $display("\n===== Mismatch WORD %0d =====",i);
                $display(" DUT    = %08x",dut_t[i*32 +:32]);
                $display(" GOLDEN = %08x",golden[(59-i)*32 +:32]);

                err = err + 1;
            end
            else begin
                $display("\n===== Matched TRUE WORD %0d =====",i);
                $display(" DUT    = %08x",dut_t[i*32 +:32]);
                $display(" GOLDEN = %08x",golden[(59-i)*32 +:32]);
            end

            if(dut_f[i*32 +:32] !== ~golden[(59-i)*32 +:32]) begin

                $display("\n===== False Rail Error WORD %0d =====",i);
                $display(" DUT_F    = %08x",dut_f[i*32 +:32]);
                $display(" EXPECTED = %08x",~golden[(59-i)*32 +:32]);

                err = err + 1;
            end
            else begin
                $display("\n===== Matched FAILED WORD %0d =====",i);
                $display(" DUT_F    = %08x",dut_f[i*32 +:32]);
                $display(" EXPECTED = %08x",~golden[(59-i)*32 +:32]);
            end

        end

        $display("---------------------------------------------");

        if(err==0)
            $display("PASS : All 60 expanded words match.");
        else
            $display("FAIL : %0d mismatches found.",err);

        $display("---------------------------------------------");

        $finish;

    end

endmodule