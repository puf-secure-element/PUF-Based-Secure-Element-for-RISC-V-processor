module aff_trans(
    input  wire [7:0]   aff_trans_in_t,
    input  wire [7:0]   aff_trans_in_f,

    output wire [7:0]   aff_trans_out_t,
    output wire [7:0]   aff_trans_out_f
);
    //True value
    assign aff_trans_out_t[0]       = aff_trans_in_t[0] ^ aff_trans_in_t[4] ^ aff_trans_in_t[5] ^ aff_trans_in_t[6] ^ aff_trans_in_t[7] ^ 1'b1;
    assign aff_trans_out_t[1]       = aff_trans_in_t[0] ^ aff_trans_in_t[1] ^ aff_trans_in_t[5] ^ aff_trans_in_t[6] ^ aff_trans_in_t[7] ^ 1'b1;
    assign aff_trans_out_t[2]       = aff_trans_in_t[0] ^ aff_trans_in_t[1] ^ aff_trans_in_t[2] ^ aff_trans_in_t[6] ^ aff_trans_in_t[7];
    assign aff_trans_out_t[3]       = aff_trans_in_t[0] ^ aff_trans_in_t[1] ^ aff_trans_in_t[2] ^ aff_trans_in_t[3] ^ aff_trans_in_t[7];
    assign aff_trans_out_t[4]       = aff_trans_in_t[0] ^ aff_trans_in_t[1] ^ aff_trans_in_t[2] ^ aff_trans_in_t[3] ^ aff_trans_in_t[4];
    assign aff_trans_out_t[5]       = aff_trans_in_t[1] ^ aff_trans_in_t[2] ^ aff_trans_in_t[3] ^ aff_trans_in_t[4] ^ aff_trans_in_t[5] ^ 1'b1;
    assign aff_trans_out_t[6]       = aff_trans_in_t[2] ^ aff_trans_in_t[3] ^ aff_trans_in_t[4] ^ aff_trans_in_t[5] ^ aff_trans_in_t[6] ^ 1'b1;
    assign aff_trans_out_t[7]       = aff_trans_in_t[3] ^ aff_trans_in_t[4] ^ aff_trans_in_t[5] ^ aff_trans_in_t[6] ^ aff_trans_in_t[7];

    //False value
    assign aff_trans_out_f[0]       = aff_trans_in_f[0] ^ aff_trans_in_f[4] ^ aff_trans_in_f[5] ^ aff_trans_in_f[6] ^ aff_trans_in_f[7] ^ 1'b1;
    assign aff_trans_out_f[1]       = aff_trans_in_f[0] ^ aff_trans_in_f[1] ^ aff_trans_in_f[5] ^ aff_trans_in_f[6] ^ aff_trans_in_f[7] ^ 1'b1;
    assign aff_trans_out_f[2]       = aff_trans_in_f[0] ^ aff_trans_in_f[1] ^ aff_trans_in_f[2] ^ aff_trans_in_f[6] ^ aff_trans_in_f[7];
    assign aff_trans_out_f[3]       = aff_trans_in_f[0] ^ aff_trans_in_f[1] ^ aff_trans_in_f[2] ^ aff_trans_in_f[3] ^ aff_trans_in_f[7];
    assign aff_trans_out_f[4]       = aff_trans_in_f[0] ^ aff_trans_in_f[1] ^ aff_trans_in_f[2] ^ aff_trans_in_f[3] ^ aff_trans_in_f[4];
    assign aff_trans_out_f[5]       = aff_trans_in_f[1] ^ aff_trans_in_f[2] ^ aff_trans_in_f[3] ^ aff_trans_in_f[4] ^ aff_trans_in_f[5] ^ 1'b1;
    assign aff_trans_out_f[6]       = aff_trans_in_f[2] ^ aff_trans_in_f[3] ^ aff_trans_in_f[4] ^ aff_trans_in_f[5] ^ aff_trans_in_f[6] ^ 1'b1;
    assign aff_trans_out_f[7]       = aff_trans_in_f[3] ^ aff_trans_in_f[4] ^ aff_trans_in_f[5] ^ aff_trans_in_f[6] ^ aff_trans_in_f[7];
endmodule