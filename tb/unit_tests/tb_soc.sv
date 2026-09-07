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
    // Debug signals
    //
    // Hierarchy:
    //
    // dut
    //  └── crypto_accelerator
    //       └── u_core
    //            ├── w_puf_response
    //            ├── w_ecc_response
    //            ├── w_sha_key
    //            └── u_aes
    //
    //------------------------------------------------------

    reg [511:0] last_puf;
    reg [511:0] last_ecc;
    reg [255:0] last_key;
    reg [127:0] last_aes;

    initial begin
        last_puf = {512{1'bx}};
        last_ecc = {512{1'bx}};
        last_key = {256{1'bx}};
        last_aes = {128{1'bx}};
    end

    // //------------------------------------------------------
    // // PUF Response
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.w_puf_response) begin

    //     if (dut.crypto_accelerator.u_core.w_puf_response !== last_puf) begin

    //         last_puf = dut.crypto_accelerator.u_core.w_puf_response;

    //         $display("");
    //         $display("==============================================================");
    //         $display("[%0t] PUF RESPONSE", $time);
    //         $display("--------------------------------------------------------------");
    //         $display("PUF Response = %0512h",
    //                  dut.crypto_accelerator.u_core.w_puf_response);
    //         $display("PUF Valid    = %b",
    //                  dut.crypto_accelerator.u_core.puf_valid);
    //         $display("==============================================================");
    //     end
    // end

    // //------------------------------------------------------
    // // ECC Response
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.w_ecc_response) begin

    //     if (dut.crypto_accelerator.u_core.w_ecc_response !== last_ecc) begin

    //         last_ecc = dut.crypto_accelerator.u_core.w_ecc_response;

    //         $display("");
    //         $display("==============================================================");
    //         $display("[%0t] ECC RESPONSE", $time);
    //         $display("--------------------------------------------------------------");
    //         $display("ECC Response = %0512h",
    //                  dut.crypto_accelerator.u_core.w_ecc_response);
    //         $display("ECC Valid    = %b",
    //                  dut.crypto_accelerator.u_core.ecc_valid);
    //         $display("==============================================================");
    //     end
    // end

    //------------------------------------------------------
    // SHA256 Key
    //
    // w_sha_key -> AES key_in
    //------------------------------------------------------
    always @(dut.crypto_accelerator.u_core.sha_start) begin


            $display("");
            $display("==============================================================");
            $display("[%0t] SHA256 KEY -> AES key_in", $time);
            $display("--------------------------------------------------------------");
            $display("key_in       = %0256h",
                     dut.crypto_accelerator.u_core.w_sha_key);
            $display("SHA Valid    = %b",
                     dut.crypto_accelerator.u_core.sha_start);
            $display("AES Start    = %b",
                     dut.crypto_accelerator.u_core.aes_start);
            $display("Key Ready    = %b",
                     dut.crypto_accelerator.u_core.sha_valid &
                     dut.crypto_accelerator.u_core.aes_start);
            $display("==============================================================");
    end

    // //------------------------------------------------------
    // // AES data_out
    // //
    // // u_aes.data_out -> aes_dout -> Reg Bank -> SoC data_out
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.aes_dout) begin

    //     if (dut.crypto_accelerator.u_core.aes_dout !== last_aes) begin

    //         last_aes = dut.crypto_accelerator.u_core.aes_dout;

    //         $display("");
    //         $display("==============================================================");
    //         $display("[%0t] AES OUTPUT", $time);
    //         $display("--------------------------------------------------------------");
    //         $display("AES data_out = %032h",
    //                  dut.crypto_accelerator.u_core.aes_dout);
    //         $display("AES done     = %b",
    //                  dut.crypto_accelerator.u_core.aes_done);
    //         $display("SoC data_out = %032h",
    //                  dut.data_out);
    //         $display("IRQ          = %b",
    //                  dut.irq);
    //         $display("==============================================================");
    //     end
    // end

    // always @(posedge clk) begin
    //     $display("[%0t] FSM state=%0d next=%0d SHA start=%0d",
    //              $time,
    //              dut.crypto_accelerator.u_fsm.current_state,
    //              dut.crypto_accelerator.u_fsm.next_state,
    //              dut.crypto_accelerator.u_fsm.sha_start);
    // end

    // //------------------------------------------------------
    // // Direct AES internal debug
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.u_aes.data_out) begin

    //     $display(
    //         "[%0t] AES INTERNAL: data_out=%032h done=%b",
    //         $time,
    //         dut.crypto_accelerator.u_core.u_aes.data_out,
    //         dut.crypto_accelerator.u_core.u_aes.done
    //     );

    // end

    // //------------------------------------------------------
    // // AES control signals
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.aes_start or
    //          dut.crypto_accelerator.u_core.aes_done) begin

    //     $display(
    //         "[%0t] AES CTRL: start=%b done=%b encrypt=%b decrypt=%b",
    //         $time,
    //         dut.crypto_accelerator.u_core.aes_start,
    //         dut.crypto_accelerator.u_core.aes_done,
    //         dut.crypto_accelerator.u_core.aes_encrypt_en,
    //         dut.crypto_accelerator.u_core.aes_decrypt_en
    //     );

    // end

    // //------------------------------------------------------
    // // PUF / ECC / SHA valid signals
    // //------------------------------------------------------
    // always @(dut.crypto_accelerator.u_core.puf_valid or
    //          dut.crypto_accelerator.u_core.ecc_valid or
    //          dut.crypto_accelerator.u_core.sha_valid) begin

    //     $display(
    //         "[%0t] VALID: PUF=%b ECC=%b SHA=%b",
    //         $time,
    //         dut.crypto_accelerator.u_core.puf_valid,
    //         dut.crypto_accelerator.u_core.ecc_valid,
    //         dut.crypto_accelerator.u_core.sha_valid
    //     );

    // end

    //------------------------------------------------------
    // Write task
    //------------------------------------------------------
    reg [31:0] tb_addr;
    reg [31:0] tb_data;

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

        rst_n   = 0;
        tb_addr = 0;
        tb_data = 0;

        #30;
        rst_n = 1;

        repeat(2) @(posedge clk);

        //--------------------------------------------------
        // Wait for system
        //--------------------------------------------------
        repeat(1000) @(posedge clk);

        $display("");
        $display("==============================================================");
        $display("             Simulation Finished");
        $display("==============================================================");

        $display("Final PUF Response = %0512h",
                 dut.crypto_accelerator.u_core.w_puf_response);

        $display("Final ECC Response = %0512h",
                 dut.crypto_accelerator.u_core.w_ecc_response);

        $display("Final SHA Key      = %0256h",
                 dut.crypto_accelerator.u_core.w_sha_key);

        $display("Final AES Output   = %032h",
                 dut.crypto_accelerator.u_core.aes_dout);

        $display("Final AES Done     = %b",
                 dut.crypto_accelerator.u_core.aes_done);

        $display("==============================================================");

        $finish;
    end

endmodule