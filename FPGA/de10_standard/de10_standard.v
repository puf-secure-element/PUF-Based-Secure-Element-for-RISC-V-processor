module de10_standard (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR,
<<<<<<< HEAD
    input  wire        UART_RXD,
    output wire        UART_TXD
=======
    input  wire        GPIO_D3,
    output wire        GPIO_D2
>>>>>>> 3e321e1 (Add FPGA UART GPIO debug output)
);

    wire [127:0] data_out;
    wire         irq;
    wire         uart_irq;

    soc u_soc (
        .clk      (CLOCK_50),
        .rst_n    (KEY[0]),
        .data_out (data_out),
        .irq      (irq),
        .uart_rxd (UART_RXD),
        .uart_txd (UART_TXD),
        .uart_irq (uart_irq)
    );

    assign LEDR[8:0] = data_out[8:0];
    assign LEDR[9]   = irq | uart_irq;

endmodule