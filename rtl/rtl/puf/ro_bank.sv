module ro_bank #(
    parameter int NUM_RO = 64
)(
    input  logic              enable,
    output logic [NUM_RO-1:0] ro_clk
);

    genvar i;
    generate
        for (i = 0; i < NUM_RO; i++) begin : RO_ARRAY
            ro_cell #(
                .ID(i) // Truyền biến i vào làm ID
            ) u_ro (
                .enable (enable),
                .ro_out (ro_clk[i])
            );
        end
    endgenerate

endmodule