module add_round_key_core(
    input  wire [7:0] key_t, key_f,
    input  wire [7:0] data_t, data_f,

    output wire [7:0] data_out_t,
    output wire [7:0] data_out_f
);

    assign data_out_t = (data_t & key_f) | (data_f & key_t);
    assign data_out_f = (data_t & key_t) | (data_f & key_f);

endmodule
