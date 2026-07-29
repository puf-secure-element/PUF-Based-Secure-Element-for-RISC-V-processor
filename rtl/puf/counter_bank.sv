module counter_bank #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24
)(
    input  logic                     counter_reset, // Asynchronous Reset từ Controller
    input  logic [NUM_RO-1:0]        ro_clk,
    output logic [COUNTER_WIDTH-1:0] count [NUM_RO]
);

    genvar i;
    generate
        for(i = 0; i < NUM_RO; i++) begin : GEN_COUNTER
            always_ff @(posedge ro_clk[i] or posedge counter_reset) begin
                if(counter_reset)
                    count[i] <= '0;
                else
                    count[i] <= count[i] + 1'b1; 
            end
        end
    endgenerate

endmodule