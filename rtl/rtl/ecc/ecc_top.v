module ecc_top (
    input  wire         clk_i,
    input  wire         rst_n_i,
    input  wire         mode_i,       // 0: Generate helper data (Enroll), 1: Reconstruct key
    input  wire         start_i,      // Start signal for ECC operation
    input  wire [511:0] raw_resp_i,   // Raw data from PUF
    input  wire [95:0]  helper_in_i,  // Helper data from external flash
    input  wire         helper_val_i, // Signal that helper data from flash is ready/valid

    output reg  [95:0]  helper_out_o, // Register for clock-domain synchronization
    output reg  [511:0] corr_resp_o,  // Register output for stable data after one clock
    output reg          corr_resp_val_o // Valid signal for downstream SHA-256 block
);

    reg [95:0] helper_reg;
    wire [95:0]  calc_helper;
    wire [511:0] decoded_resp;

    // Generate 16 parallel segments
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ecc_segments

            hamming_encoder_32 enc_inst (
                .data_i  (raw_resp_i[i*32 +: 32]),
                .parity_o(calc_helper[i*6 +: 6])
            );

            hamming_decoder_32 dec_inst (
                .noisy_data_i(raw_resp_i[i*32 +: 32]),
                .parity_i    (helper_reg[i*6 +: 6]),
                .corr_data_o (decoded_resp[i*32 +: 32])
            );

        end
    endgenerate

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            helper_reg <= 96'h0;
        end else if (start_i && (mode_i == 1'b0)) begin
            helper_reg <= calc_helper;  
        end
    end

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            corr_resp_o     <= 512'h0;
            helper_out_o    <= 96'h0;
            corr_resp_val_o <= 1'b0;
        // end else begin
           // corr_resp_o  <= (mode_i == 1'b1) ? decoded_resp : raw_resp_i;
            //helper_out_o <= calc_helper;

            // Generate valid signal for downstream SHA-256 block
//            if (mode_i == 1'b1) begin
    //            corr_resp_val_o <= helper_val_i; // Valid only when helper data has been loaded
  //          end else begin
      //          corr_resp_val_o <= 1'b1; // Enroll mode is ready after one clock
        //    end
        end else if (start_i) begin
            corr_resp_o  <= (mode_i == 1'b1) ? decoded_resp : raw_resp_i;
            helper_out_o <= calc_helper;
            corr_resp_val_o <= 1'b1;
        end else begin
            corr_resp_val_o <= 1'b0; // Reset valid signal when not processing
        end
    end

endmodule
