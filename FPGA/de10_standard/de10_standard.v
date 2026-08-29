module de10_standard (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR
);

    wire [127:0] data_out;
    wire         irq;

    soc u_soc (
        .clk      (CLOCK_50),
        .rst_n    (KEY[0]),
        .data_out (data_out),
        .irq      (irq)
    );

    assign LEDR[8:0] = data_out[8:0];
    assign LEDR[9]   = irq;

endmodule