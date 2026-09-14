module de10_standard (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR,
    input  wire        UART_RXD,
    output wire        UART_TXD
);

    wire [127:0] data_out;
    wire         irq;
    wire         aes_done;

    soc u_soc (
        .clk       (CLOCK_50),
        .rst_n     (KEY[0]),
        .data_out  (data_out),
        .aes_done  (aes_done),
        .uart_rxd  (UART_RXD),
        .uart_txd  (UART_TXD),
        .uart_irq  (irq)
    );

    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // Free-running counter wired straight to CLOCK_50/KEY[0], with zero
    // dependency on `soc` (no PUF, UART, CPU, or AES involved at all).
    // If LEDR[9] does not visibly blink (~0.7s period) on real hardware,
    // the problem is at the board / programming / clock / JTAG level --
    // not anywhere inside the SoC design, since this path never touches it.
    reg [25:0] diag_counter;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            diag_counter <= 26'd0;
        else
            diag_counter <= diag_counter + 26'd1;
    end

    assign LEDR[8:0] = data_out[8:0];
    assign LEDR[9]   = diag_counter[25];

endmodule