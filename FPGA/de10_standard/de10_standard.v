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
    // dependency on `soc`. Confirmed already: this blinks fine on real
    // hardware, proving board/clock/JTAG/programming are all healthy.
    reg [25:0] diag_counter;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            diag_counter <= 26'd0;
        else
            diag_counter <= diag_counter + 26'd1;
    end

    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // irq/LEDR9 turned out to be a dead end: uart_interrupt.v ANDs every
    // status bit with an "enable" input (en_tx_fifo_full etc.) that only a
    // CPU register write can set, and nothing in Instruction_memory.v's
    // firmware ever writes it -- so interrupt is permanently 0 by design,
    // completely independent of whether UART/CPU/PUF are actually alive.
    // Every LEDR9-based test result so far (PUF bypass, PUF removal,
    // UART-only isolation) was uninformative because of this, not because
    // those subsystems were broken.
    // UART_TXD idles at logic 1 (mark/idle) the moment the transmitter
    // comes out of reset (see uart_transmiter.v: tx_shift_data <= 9'h1 on
    // reset), with no enable-bit gating at all -- a real "is uart_top
    // alive" signal. Mirror it onto LEDR9 so it's visible without a scope.
    assign LEDR[7:0] = data_out[7:0];
    assign LEDR[8]   = diag_counter[25];
    assign LEDR[9]   = UART_TXD;

endmodule