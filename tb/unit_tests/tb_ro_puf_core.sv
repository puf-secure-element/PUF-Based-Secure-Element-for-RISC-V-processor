module tb_ro_puf_core;

    parameter CLK_PERIOD = 50;

    logic clk;
    logic rst_n;

    logic start;
    logic [31:0] measure_window;
    logic [15:0] challenge;

    logic [511:0] response;
    logic response_ready;
    logic core_busy;

    //------------------------------------------------------------
    // DUT
    //------------------------------------------------------------
    ro_puf_core dut(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .measure_window(measure_window),
        .challenge(challenge),
        .response(response),
        .response_ready(response_ready),
        .core_busy(core_busy)
    );

    //------------------------------------------------------------
    // Clock 50ns
    //------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //------------------------------------------------------------
    // Clock Counter
    //------------------------------------------------------------
    integer cycle_cnt;

    always @(posedge clk) begin
        if (!rst_n)
            cycle_cnt <= 0;
        else begin
            cycle_cnt <= cycle_cnt + 1;

            $display("[%0t] Cycle=%0d  Busy=%0b  Ready=%0b",
                     $time, cycle_cnt, core_busy, response_ready);

            if (response_ready) begin
                $display("--------------------------------");
                $display("Response Ready!");
                $display("Total Cycles = %0d", cycle_cnt);
                $display("Response = %h", response);
                $display("--------------------------------");
                $finish;
            end
        end
    end

    //------------------------------------------------------------
    // Stimulus
    //------------------------------------------------------------
    initial begin

        rst_n = 0;
        start = 0;

        measure_window = 32'd50;      
        challenge = 16'h1234;

        #(CLK_PERIOD*2);

        rst_n = 1;

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

    end

endmodule