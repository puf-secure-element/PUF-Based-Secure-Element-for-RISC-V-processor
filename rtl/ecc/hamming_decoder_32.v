module hamming_decoder_32 (
    input  wire [31:0] noisy_data_i,
    input  wire [5:0]  parity_i,
<<<<<<< HEAD
    output reg  [31:0] corr_data_o 
=======
    output reg  [31:0] corr_data_o
>>>>>>> 465bda21df2f34c1f9a4d8e71e18467d10919020
);
    wire [5:0]  calc_parity;
    wire [5:0]  syndrome;
    reg  [37:0] codeword;
    
    hamming_encoder_32 re_encoder (
        .data_i  (noisy_data_i),
        .parity_o(calc_parity)
    );
    
    assign syndrome = calc_parity ^ parity_i;
    
    always @(*) begin
        codeword = 38'h0;
        codeword[0]  = parity_i[0];
        codeword[1]  = parity_i[1];
        codeword[3]  = parity_i[2];
        codeword[7]  = parity_i[3];
        codeword[15] = parity_i[4];
        codeword[31] = parity_i[5];
        
        codeword[2]   = noisy_data_i[0];  codeword[4]   = noisy_data_i[1];  codeword[5]   = noisy_data_i[2];
        codeword[6]   = noisy_data_i[3];  codeword[8]   = noisy_data_i[4];  codeword[9]   = noisy_data_i[5];
        codeword[10]  = noisy_data_i[6];  codeword[11]  = noisy_data_i[7];  codeword[12]  = noisy_data_i[8];
        codeword[13]  = noisy_data_i[9];  codeword[14]  = noisy_data_i[10]; codeword[16]  = noisy_data_i[11];
        codeword[17]  = noisy_data_i[12]; codeword[18]  = noisy_data_i[13]; codeword[19]  = noisy_data_i[14];
        codeword[20]  = noisy_data_i[15]; codeword[21]  = noisy_data_i[16]; codeword[22]  = noisy_data_i[17];
        codeword[23]  = noisy_data_i[18]; codeword[24]  = noisy_data_i[19]; codeword[25]  = noisy_data_i[20];
        codeword[26]  = noisy_data_i[21]; codeword[27]  = noisy_data_i[22]; codeword[28]  = noisy_data_i[23];
        codeword[29]  = noisy_data_i[24]; codeword[30]  = noisy_data_i[25]; codeword[32]  = noisy_data_i[26];
        codeword[33]  = noisy_data_i[27]; codeword[34]  = noisy_data_i[28]; codeword[35]  = noisy_data_i[29];
        codeword[36]  = noisy_data_i[30]; codeword[37]  = noisy_data_i[31];
        
        if (syndrome != 6'b000000) begin
            codeword[syndrome - 1] = ~codeword[syndrome - 1];
        end
        
        corr_data_o[0]  = codeword[2];   corr_data_o[1]  = codeword[4];   corr_data_o[2]  = codeword[5];
        corr_data_o[3]  = codeword[6];   corr_data_o[4]  = codeword[8];   corr_data_o[5]  = codeword[9];
        corr_data_o[6]  = codeword[10];  corr_data_o[7]  = codeword[11];  corr_data_o[8]  = codeword[12];
        corr_data_o[9]  = codeword[13];  corr_data_o[10] = codeword[14];  corr_data_o[11] = codeword[16];
        corr_data_o[12] = codeword[17];  corr_data_o[13] = codeword[18];  corr_data_o[14] = codeword[19];
        corr_data_o[15] = codeword[20];  corr_data_o[16] = codeword[21];  corr_data_o[17] = codeword[22];
        corr_data_o[18] = codeword[23];  corr_data_o[19] = codeword[24];  corr_data_o[20] = codeword[25];
        corr_data_o[21] = codeword[26];  corr_data_o[22] = codeword[27];  corr_data_o[23] = codeword[28];
        corr_data_o[24] = codeword[29];  corr_data_o[25] = codeword[30];  corr_data_o[26] = codeword[32];
        corr_data_o[27] = codeword[33];  corr_data_o[28] = codeword[34];  corr_data_o[29] = codeword[35];
        corr_data_o[30] = codeword[36];  corr_data_o[31] = codeword[37];
    end
endmodule
