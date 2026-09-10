module de10_standard (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR,
    input  wire        UART_RXD,
    output wire        UART_TXD
);

    wire [127:0] data_out;
    wire         irq;
    wire         uart_irq;
    reg          clk_25;
    reg [25:0]   blink_counter;

    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            clk_25 <= 1'b0;
        end else begin
            clk_25 <= ~clk_25;
        end
    end

    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            blink_counter <= 26'd0;
        end else begin
            blink_counter <= blink_counter + 1'b1;
        end
    end

    soc u_soc (
        .clk      (clk_25),
        .rst_n    (KEY[0]),
        .data_out (data_out),
        .irq      (irq),
        .uart_rxd (UART_RXD),
        .uart_txd (UART_TXD),
        .uart_irq (uart_irq)
    );

    // LEDR outputs are active-low on the DE10-Standard board.
    // Bit 25 changes about once every 0.67 seconds at 50 MHz.
    assign LEDR[0] = ~KEY[0];
	 assign LEDR[9:1] = 9'b0;

endmodule