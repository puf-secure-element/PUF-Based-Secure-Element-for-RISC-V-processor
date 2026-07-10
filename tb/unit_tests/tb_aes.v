`timescale 1ns/1ps

module tb_aes;

    reg             clk;
    reg             rst_n;

    reg             decrypt;
    reg             encrypt;

    reg     [127:0] plaintext;
    reg             key_is_ready;
    reg     [255:0] key_in;

    wire    [127:0] data_out;
    wire            done;

    reg     [127:0] cipher_save;

    aes dut(
        .clk          (clk),
        .rst_n        (rst_n),
        .decrypt      (decrypt),
        .encrypt      (encrypt),
        .plaintext    (plaintext),
        .key_is_ready (key_is_ready),
        .key_in       (key_in),
        .data_out     (data_out),
        .done         (done)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        rst_n        = 0;
        encrypt      = 0;
        decrypt      = 0;
        key_is_ready = 0;
        plaintext    = 0;
        key_in       = 0;

        #20;
        rst_n = 1;

        $display("\n===== First Case =====\n");
        key_in = 256'h000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F;
        plaintext = 128'h00112233445566778899AABBCCDDEEFF;

        @(posedge clk);
        key_is_ready <= 1'b1;
        encrypt      <= 1'b1;
        decrypt      <= 1'b0;

        @(posedge clk);
        encrypt <= 1'b0;

        @(posedge done);

        cipher_save = data_out;

        $display("\n==============================");
        $display("Encryption Finished");
        $display("Plaintext  = %h", plaintext);
        $display("Ciphertext = %h", cipher_save);
        $display("==============================\n");


        @(posedge clk);

        plaintext = cipher_save;

        @(posedge clk);
        decrypt <= 1'b1;
        encrypt <= 1'b0;

        @(posedge clk);
        decrypt <= 1'b0;

        @(posedge done);

        $display("\n==============================");
        $display("Decryption Finished");
        $display("Ciphertext = %h", cipher_save);
        $display("Recovered  = %h", data_out);
        $display("==============================\n");

        if (data_out == 128'h00112233445566778899AABBCCDDEEFF)
            $display("******** PASS ********");
        else
            $display("******** FAIL ********");

        #20;

        $display("\n===== Second Case =====\n");

        plaintext = 128'h6BC1BEE22E409F96E93D7E117393172A;

        @(posedge clk);
        key_is_ready <= 1'b1;
        encrypt      <= 1'b1;
        decrypt      <= 1'b0;

        @(posedge clk);
        encrypt <= 1'b0;

        @(posedge done);

        cipher_save = data_out;

        $display("\n==============================");
        $display("Encryption Finished");
        $display("Plaintext  = %h", plaintext);
        $display("Ciphertext = %h", cipher_save);
        $display("==============================\n");


        @(posedge clk);

        plaintext = cipher_save;

        @(posedge clk);
        decrypt <= 1'b1;
        encrypt <= 1'b0;

        @(posedge clk);
        decrypt <= 1'b0;

        @(posedge done);

        $display("\n==============================");
        $display("Decryption Finished");
        $display("Ciphertext = %h", cipher_save);
        $display("Recovered  = %h", data_out);
        $display("==============================\n");

        if (data_out == 128'h6BC1BEE22E409F96E93D7E117393172A)
            $display("******** PASS ********");
        else
            $display("******** FAIL ********");

        #20;

        $display("\n===== Third Case =====\n");

        plaintext = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        @(posedge clk);
        key_is_ready <= 1'b1;
        encrypt      <= 1'b1;
        decrypt      <= 1'b0;

        @(posedge clk);
        encrypt <= 1'b0;

        @(posedge done);

        cipher_save = data_out;

        $display("\n==============================");
        $display("Encryption Finished");
        $display("Plaintext  = %h", plaintext);
        $display("Ciphertext = %h", cipher_save);
        $display("==============================\n");


        @(posedge clk);

        plaintext = cipher_save;

        @(posedge clk);
        decrypt <= 1'b1;
        encrypt <= 1'b0;

        @(posedge clk);
        decrypt <= 1'b0;

        @(posedge done);

        $display("\n==============================");
        $display("Decryption Finished");
        $display("Ciphertext = %h", cipher_save);
        $display("Recovered  = %h", data_out);
        $display("==============================\n");

        if (data_out == 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            $display("******** PASS ********");
        else
            $display("******** FAIL ********");

        #20;
        $finish;

    end

    always @(posedge clk) begin
        $display("----------------------------------------------");
        $display("T         : %0t", $time);
        $display("encrypt   : %b", encrypt);
        $display("decrypt   : %b", decrypt);
        $display("done      : %b", done);
        $display("input     : %h", plaintext);
        $display("output    : %h", data_out);
        $display("----------------------------------------------");
    end

    

endmodule