module hamming_encoder_32 (
    input  wire [31:0] data_i,
    output wire [5:0]  parity_o 
);
    assign parity_o[0] = data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4] ^ data_i[6] ^ data_i[8] ^ 
                         data_i[10] ^ data_i[11] ^ data_i[13] ^ data_i[15] ^ data_i[17] ^ data_i[19] ^ 
                         data_i[21] ^ data_i[23] ^ data_i[25] ^ data_i[26] ^ data_i[28] ^ data_i[30];
                         
    assign parity_o[1] = data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[5] ^ data_i[6] ^ data_i[9] ^ 
                         data_i[10] ^ data_i[12] ^ data_i[13] ^ data_i[16] ^ data_i[17] ^ data_i[20] ^ 
                         data_i[21] ^ data_i[24] ^ data_i[25] ^ data_i[27] ^ data_i[28] ^ data_i[31];
                         
    assign parity_o[2] = data_i[1] ^ data_i[2] ^ data_i[3] ^ data_i[7] ^ data_i[8] ^ data_i[9] ^ 
                         data_i[10] ^ data_i[14] ^ data_i[15] ^ data_i[16] ^ data_i[17] ^ data_i[22] ^ 
                         data_i[23] ^ data_i[24] ^ data_i[25] ^ data_i[29] ^ data_i[30] ^ data_i[31];
                         
    assign parity_o[3] = data_i[4] ^ data_i[5] ^ data_i[6] ^ data_i[7] ^ data_i[8] ^ data_i[9] ^ 
                         data_i[10] ^ data_i[18] ^ data_i[19] ^ data_i[20] ^ data_i[21] ^ data_i[22] ^ 
                         data_i[23] ^ data_i[24] ^ data_i[25];
                         
    assign parity_o[4] = data_i[11] ^ data_i[12] ^ data_i[13] ^ data_i[14] ^ data_i[15] ^ data_i[16] ^ 
                         data_i[17] ^ data_i[18] ^ data_i[19] ^ data_i[20] ^ data_i[21] ^ data_i[22] ^ 
                         data_i[23] ^ data_i[24] ^ data_i[25];
                         
    assign parity_o[5] = data_i[26] ^ data_i[27] ^ data_i[28] ^ data_i[29] ^ data_i[30] ^ data_i[31];
endmodule
