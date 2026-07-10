`timescale 1ns/1ps

module tb_sub_bytes;

    //--------------------------------------------------
    // Inputs
    //--------------------------------------------------
    reg         en;
    reg         de;
    reg [31:0]  data_in_t;
    reg [31:0]  data_in_f;

    //--------------------------------------------------
    // Outputs
    //--------------------------------------------------
    wire [31:0] data_out_t;
    wire [31:0] data_out_f;

    //--------------------------------------------------
    // DUT
    //--------------------------------------------------
    sub_bytes dut(
        .en(en),
        .de(de),
        .data_in_t(data_in_t),
        .data_in_f(data_in_f),
        .data_out_t(data_out_t),
        .data_out_f(data_out_f)
    );

    //--------------------------------------------------
    // Golden AES S-box
    //--------------------------------------------------
    wire [7:0] exp0, exp1, exp2, exp3;

    aes_sbox_golden sbox0(
        .a(data_in_t[7:0]),
        .c(exp0)
    );

    aes_sbox_golden sbox1(
        .a(data_in_t[15:8]),
        .c(exp1)
    );

    aes_sbox_golden sbox2(
        .a(data_in_t[23:16]),
        .c(exp2)
    );

    aes_sbox_golden sbox3(
        .a(data_in_t[31:24]),
        .c(exp3)
    );

    wire [31:0] expected;

    assign expected = {exp3, exp2, exp1, exp0};

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    //--------------------------------------------------
    // Task
    //--------------------------------------------------
    task run_case;
        input [31:0] t_data;
    begin

        en        = 1'b1;
        de        = 1'b0;

        data_in_t = t_data;
        data_in_f = ~t_data;

        #10;

        $display("==================================================");
        $display("Input             : %h", data_in_t);
        $display("SBOX Expected     : %h", expected);
        $display("Sub Bytes Output  : %h", data_out_t);

        //------------------------------
        // Compare
        //------------------------------
        if(data_out_t === expected) begin
            $display("SBOX CHECK : PASS");
            pass_cnt = pass_cnt + 1;
        end
        else begin
            $display("SBOX CHECK : FAIL");
            fail_cnt = fail_cnt + 1;
        end

        //------------------------------
        // Dual rail check
        //------------------------------
        if(data_out_f === ~data_out_t)
            $display("Dual Rail  : PASS");
        else
            $display("Dual Rail  : FAIL");

        //------------------------------
        // Byte-by-byte comparison
        //------------------------------
        if(data_out_t[31:24] == exp3)
            $display("Byte3 PASS");
        else
            $display("Byte3 FAIL  exp=%02h act=%02h",
                     exp3,data_out_t[31:24]);

        if(data_out_t[23:16] == exp2)
            $display("Byte2 PASS");
        else
            $display("Byte2 FAIL  exp=%02h act=%02h",
                     exp2,data_out_t[23:16]);

        if(data_out_t[15:8] == exp1)
            $display("Byte1 PASS");
        else
            $display("Byte1 FAIL  exp=%02h act=%02h",
                     exp1,data_out_t[15:8]);

        if(data_out_t[7:0] == exp0)
            $display("Byte0 PASS");
        else
            $display("Byte0 FAIL  exp=%02h act=%02h",
                     exp0,data_out_t[7:0]);

    end
    endtask

    //--------------------------------------------------
    // Test
    //--------------------------------------------------
    initial begin

        en        = 0;
        de        = 0;
        data_in_t = 0;
        data_in_f = 32'hFFFFFFFF;

        #20;

        $display("\n========== SUB_BYTES ENCRYPTION TEST ==========\n");

        run_case(32'h00112233);
        run_case(32'h01234567);
        run_case(32'h89ABCDEF);
        run_case(32'hFFFFFFFF);
        run_case(32'h00000000);
        run_case(32'h12345678);
        run_case(32'hDEADBEEF);
        run_case(32'hCAFEBABE);
        run_case(32'hA5A5A5A5);
        run_case(32'h5A5A5A5A);

        //--------------------------------------------------
        // Random Tests
        //--------------------------------------------------
        repeat(50)
            run_case($random);

        //--------------------------------------------------
        // Summary
        //--------------------------------------------------
        $display("\n======================================");
        $display("PASS = %0d", pass_cnt);
        $display("FAIL = %0d", fail_cnt);
        $display("======================================");

        if(fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #20;
        $finish;

    end

endmodule