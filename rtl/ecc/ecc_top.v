module ecc_top (
    //input  wire         clk_i,
    //input  wire         rst_n_i,
    input  wire         mode_i,       
    input  wire [511:0] raw_resp_i,  
    input  wire [95:0]  helper_in_i,  
    
    output wire [95:0]  helper_out_o, 
    output wire [511:0] corr_resp_o   
);

 wire [511:0] decoded_resp;
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ecc_segments
            
            hamming_encoder_32 enc_inst (
                .data_i  (raw_resp_i[i*32 +: 32]),
                .parity_o(helper_out_o[i*6 +: 6])
            );
            
            hamming_decoder_32 dec_inst (
                .noisy_data_i(raw_resp_i[i*32 +: 32]),
                .parity_i    (helper_in_i[i*6 +: 6]),
                .corr_data_o (decoded_resp[i*32 +: 32])
            );
            
        end
    endgenerate

     assign corr_resp_o = (mode_i == 1'b1) ? decoded_resp : raw_resp_i;
endmodule
