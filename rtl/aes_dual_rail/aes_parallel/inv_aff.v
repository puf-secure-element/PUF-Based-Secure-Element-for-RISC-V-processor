module inv_aff(
    input  wire [7:0]   inv_aff_in_t,
    input  wire [7:0]   inv_aff_in_f,

    output wire [7:0]   inv_aff_out_t,
    output wire [7:0]   inv_aff_out_f
);
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
    assign inv_aff_out_f[2]       = inv_aff_in_f[1] ^ inv_aff_in_f[4] ^ inv_aff_in_f[7] ^ 1'b1;
    assign inv_aff_out_f[3]       = inv_aff_in_f[0] ^ inv_aff_in_f[2] ^ inv_aff_in_f[5];
    assign inv_aff_out_f[4]       = inv_aff_in_f[1] ^ inv_aff_in_f[3] ^ inv_aff_in_f[6];
    assign inv_aff_out_f[5]       = inv_aff_in_f[2] ^ inv_aff_in_f[4] ^ inv_aff_in_f[7];
    assign inv_aff_out_f[6]       = inv_aff_in_f[0] ^ inv_aff_in_f[3] ^ inv_aff_in_f[5];
    assign inv_aff_out_f[7]       = inv_aff_in_f[1] ^ inv_aff_in_f[4] ^ inv_aff_in_f[6];
    
endmodule