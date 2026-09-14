`timescale 1ns/1ps

module tb_uart_cfg;

    reg  clk;
    reg  rst_n;
    wire [127:0] data_out;
    wire         aes_done;
    wire         uart_txd;
    wire         uart_irq;

    soc dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_out (data_out),
        .aes_done (aes_done),
        .uart_rxd (1'b1),
        .uart_txd (uart_txd),
        .uart_irq (uart_irq)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer i;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;

        $display("");
        $display("=== pipeline trace ===");
        $display("  time   pc   ifid_instr  idex_rd  wb_rd wb_en wb_data   hz bus flush");

        for (i = 0; i < 60; i = i + 1) begin
            @(posedge clk);
            $display("  %6t %03h  %08h    %2d      %2d    %b   %08h   %b  %b   %b",
                     $time,
                     dut.rv32.pc[11:0],
                     dut.rv32.IF_ID_Instruction,
                     dut.rv32.ID_EX_rd,
                     dut.rv32.MEM_WB_rd,
                     dut.rv32.MEM_WB_RegWrite,
                     dut.rv32.write_data,
                     dut.rv32.hazard_stall,
                     dut.rv32.bus_stall,
                     dut.rv32.Flush);
        end

        $display("");
        $display("=== cpu register file ===");
        $display("  x6  = 0x%08h   (expect 0x00000000)", dut.rv32.RF0.in_registers[6]);
        $display("  x7  = 0x%08h   (expect 0x00001000)", dut.rv32.RF0.in_registers[7]);
        $display("  x28 = 0x%08h   (expect 0x0000001B)", dut.rv32.RF0.in_registers[28]);
        $display("  x29 = 0x%08h   (expect 0x00000023)", dut.rv32.RF0.in_registers[29]);

        $display("");
        $display("=== uart config registers ===");
        $display("  reg_mdr = 0x%02h   (expect 0x00)", dut.u_uart.u_apb.reg_mdr);
        $display("  reg_dll = 0x%02h   (expect 0x1B)", dut.u_uart.u_apb.reg_dll);
        $display("  reg_dlh = 0x%02h   (expect 0x00)", dut.u_uart.u_apb.reg_dlh);
        $display("  reg_lcr = 0x%02h   (expect 0x23)", dut.u_uart.u_apb.reg_lcr);
        $display("  bge                = %b   (expect 1)",
                 dut.u_uart.u_apb.reg_lcr[5]);

        $display("");
        if (dut.u_uart.u_apb.reg_lcr[5] === 1'b1 &&
            dut.u_uart.u_apb.reg_dll === 8'h1B &&
            dut.u_uart.u_apb.reg_dlh === 8'h00 &&
            dut.u_uart.u_apb.reg_lcr === 8'h23)
            $display("  RESULT: PASS - uart is configured for 115200 8N1");
        else
            $display("  RESULT: FAIL - see the register values above");

        $display("");
        $finish;
    end

    initial begin
        #500000;
        $display("GLOBAL TIMEOUT - cpu is probably stalled on the bus");
        $finish;
    end

endmodule