module snapshot_register #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     snapshot_en,
    input  logic [COUNTER_WIDTH-1:0] count_in [NUM_RO],
    
    output logic [COUNTER_WIDTH-1:0] snapshot_out [NUM_RO]
);

    genvar i;
    generate
        for(i = 0; i < NUM_RO; i++) begin : GEN_SNAP
            always_ff @(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    snapshot_out[i] <= '0;
                else if(snapshot_en)
                    snapshot_out[i] <= count_in[i]; 
            end
        end
    endgenerate

endmodule