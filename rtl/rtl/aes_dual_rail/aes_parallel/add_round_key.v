module add_round_key(
    input   [127:0]     key_t,
    input   [127:0]     key_f,
    input   [127:0]     data_t,
    input   [127:0]     data_f,

    output  [127:0]     data_out_t,
    output  [127:0]     data_out_f
);

    assign data_out_t = (data_t & key_f) | (data_f & key_t);
    assign data_out_f = (data_t & key_t) | (data_f & key_f);    

endmodule