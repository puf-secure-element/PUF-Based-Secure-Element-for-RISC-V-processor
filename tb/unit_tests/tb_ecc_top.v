`timescale 1ns/1ps

module tb_ecc_top;

    reg         clk;
    reg         rst_n;
    reg         mode;

    reg  [511:0] raw_resp;
    reg  [95:0]  helper_in;

    wire [95:0]  helper_out;
    wire [511:0] corr_resp;
    wire         done;

    // Golden response
    reg [511:0] expected_resp;

    ecc_top dut(
        .clk_i(clk),
        .rst_n_i(rst_n),
        .mode_i(mode),
        .raw_resp_i(raw_resp),
        .helper_in_i(helper_in),
        .helper_out_o(helper_out),
        .corr_resp_o(corr_resp),
        .done_o(done)
    );

    //---------------- Clock ----------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //---------------- Monitor ----------------
    initial begin
        $display("time\tclk rst mode done");
        $monitor("%0t\t%b   %b   %b    %b",
                  $time,
                  clk,
                  rst_n,
                  mode,
                  done);
    end

    //---------------- Compare ----------------
    always @(posedge clk) begin
        if (done) begin
            if (mode == 0) begin
                $display("\n===== Enrollment Done =====");
                $display("Helper = %h", helper_out);
            end
            else begin
                $display("\n===== Reconstruction Done =====");
                if (corr_resp === expected_resp) begin
                    $display("PASS!");
                    $display("Expected : %h", expected_resp);
                    $display("Received : %h", corr_resp);
                end
                else begin
                    $display("FAIL!");
                    $display("Expected : %h", expected_resp);
                    $display("Received : %h", corr_resp);
                end
            end
        end
    end

    //---------------- Stimulus ----------------
    initial begin

        rst_n     = 0;
        mode      = 0;
        raw_resp  = 512'h0;
        helper_in = 96'h0;

        repeat(2) @(posedge clk);
        rst_n = 1;

        //---------------- mode 0 ----------------
        raw_resp = 512'h0123456789ABCDEF_FEDCBA987654321000112233445566778899AABBCCDDEEFF0123456789ABCDEF_FEDCBA9876543210;

        // Lưu golden response
        expected_resp = raw_resp;

        repeat(5) @(posedge clk);

        // Helper sinh ra sẽ dùng cho reconstruction
        helper_in = helper_out;

        //---------------- mode 1 ----------------
        mode = 1;

        repeat(5) @(posedge clk);

        //---------------- Inject lỗi ----------------
        raw_resp = expected_resp;

        raw_resp[0]   = ~raw_resp[0];
        raw_resp[35]  = ~raw_resp[35];
        raw_resp[200] = ~raw_resp[200];

        repeat(5) @(posedge clk);

        //---------------- quay lại mode 0 ----------------
        mode = 0;

        repeat(5) @(posedge clk);

        $finish;

    end

endmodule