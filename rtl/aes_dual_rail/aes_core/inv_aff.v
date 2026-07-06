module inv_aff(
    input  wire [7:0]   inv_aff_in_t,
    input  wire [7:0]   inv_aff_in_f,

    output wire [7:0]   inv_aff_out_t,
    output wire [7:0]   inv_aff_out_f
);
    wire aff_out_t0, aff_out_t1, aff_out_t2, aff_out_t3, aff_out_t4, aff_out_t5, aff_out_t6, aff_out_t7;
    wire aff_out_f0, aff_out_f1, aff_out_f2, aff_out_f3, aff_out_f4, aff_out_f5, aff_out_f6, aff_out_f7;
  
    //True value
    assign inv_aff_out_t[0]       = inv_aff_in_t[2] ^ inv_aff_in_t[5] ^ inv_aff_in_t[7] ^ 1'b1;
    assign inv_aff_out_t[1]       = inv_aff_in_t[0] ^ inv_aff_in_t[3] ^ inv_aff_in_t[6];
    assign inv_aff_out_t[2]       = inv_aff_in_t[1] ^ inv_aff_in_t[4] ^ inv_aff_in_t[7] ^ 1'b1;
    assign inv_aff_out_t[3]       = inv_aff_in_t[0] ^ inv_aff_in_t[2] ^ inv_aff_in_t[5];
    assign inv_aff_out_t[4]       = inv_aff_in_t[1] ^ inv_aff_in_t[3] ^ inv_aff_in_t[6];
    assign inv_aff_out_t[5]       = inv_aff_in_t[2] ^ inv_aff_in_t[4] ^ inv_aff_in_t[7];
    assign inv_aff_out_t[6]       = inv_aff_in_t[0] ^ inv_aff_in_t[3] ^ inv_aff_in_t[5];
    assign inv_aff_out_t[7]       = inv_aff_in_t[1] ^ inv_aff_in_t[4] ^ inv_aff_in_t[6];
  
    //False value
    assign inv_aff_out_f[0]       = inv_aff_in_f[2] ^ inv_aff_in_f[5] ^ inv_aff_in_f[7] ^ 1'b1;
    assign inv_aff_out_f[1]       = inv_aff_in_f[0] ^ inv_aff_in_f[3] ^ inv_aff_in_f[6];
    assign inv_aff_out_f[2]       = inv_aff_in_f[1] ^ inv_aff_in_f[1] ^ inv_aff_in_f[2] ^ 1'b1;
    assign inv_aff_out_f[3]       = inv_aff_in_f[0] ^ inv_aff_in_f[1] ^ inv_aff_in_f[2];
    assign inv_aff_out_f[4]       = inv_aff_in_f[0] ^ inv_aff_in_f[1] ^ inv_aff_in_f[2];
    assign inv_aff_out_f[5]       = inv_aff_in_f[1] ^ inv_aff_in_f[2] ^ inv_aff_in_f[3];
    assign inv_aff_out_f[6]       = inv_aff_in_f[2] ^ inv_aff_in_f[3] ^ inv_aff_in_f[4];
    assign inv_aff_out_f[7]       = inv_aff_in_f[3] ^ inv_aff_in_f[4] ^ inv_aff_in_f[5];
endmodule