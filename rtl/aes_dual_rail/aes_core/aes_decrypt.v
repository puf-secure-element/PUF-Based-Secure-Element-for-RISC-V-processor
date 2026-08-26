module aes_decrypt(
    input   wire                is_initial_round, 
    input   wire                is_final_round,     

    input   wire    [127:0]     data_t,
    input   wire    [127:0]     data_f,
    input   wire    [127:0]     key_t,
    input   wire    [127:0]     key_f,

    output  wire    [127:0]     data_out_t,
    output  wire    [127:0]     data_out_f
);

    wire [127:0] isr_out_t, isr_out_f;   
    wire [127:0] isb_out_t, isb_out_f;  
    wire [127:0] ark_out_t, ark_out_f;   
    wire [127:0] imc_out_t, imc_out_f;   
    wire [127:0] ark_in_t, ark_in_f;

    assign ark_in_t = is_initial_round ? data_t : isb_out_t;
    assign ark_in_f = is_initial_round ? data_f : isb_out_f;

    inv_shift_rows isr_inst (
        .data_in_t(data_t),
        .data_in_f(data_f),
        .shifted_data_t(isr_out_t),
        .shifted_data_f(isr_out_f)
    );

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : loop
            sub_bytes sb_inst (
                .en(1'b0),
                .de(1'b1),
                .data_in_t(isr_out_t[c*32 +: 32]),
                .data_in_f(isr_out_f[c*32 +: 32]),
                .data_out_t(isb_out_t[c*32 +: 32]),
                .data_out_f(isb_out_f[c*32 +: 32])
            );
        end
    endgenerate

    add_round_key ark_inst (
        .key_t(key_t),
        .key_f(key_f),
        .data_t(ark_in_t),
        .data_f(ark_in_f),
        .data_out_t(ark_out_t),
        .data_out_f(ark_out_f)
    );

    inv_mix_columns imc_inst (
        .data_in_t(ark_out_t),
        .data_in_f(ark_out_f),
        .data_out_t(imc_out_t),
        .data_out_f(imc_out_f)
    );

    assign data_out_t = (is_initial_round || is_final_round) ? ark_out_t : imc_out_t;
    assign data_out_f = (is_initial_round || is_final_round) ? ark_out_f : imc_out_f;

endmodule