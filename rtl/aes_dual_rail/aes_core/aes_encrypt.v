module aes_encrypt(
    input   wire                is_initial_round,  // round 0: CHỈ AddRoundKey, bỏ qua SubBytes/ShiftRows/MixColumns
    input   wire                is_final_round,     // round cuối (14 với AES-256): bỏ qua MixColumns

    input   wire    [127:0]     data_t,
    input   wire    [127:0]     data_f,
    input   wire    [127:0]     key_t,
    input   wire    [127:0]     key_f,

    output  wire    [127:0]     data_out_t,
    output  wire    [127:0]     data_out_f
);

    wire [127:0] sb_out_t, sb_out_f;
    wire [127:0] sr_out_t, sr_out_f;
    wire [127:0] mc_out_t, mc_out_f;
    wire [127:0] ark_in_t, ark_in_f;

    assign ark_in_t =   is_initial_round ? data_t : 
                        (is_final_round ? sr_out_t : mc_out_t);

    assign ark_in_f =   is_initial_round ? data_f : 
                        (is_final_round ? sr_out_f : mc_out_f);

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : loop
            sub_bytes sb_inst (
                .en(1'b1), 
                .de(1'b0),  
                .data_in_t(data_t[c*32 +: 32]),
                .data_in_f(data_f[c*32 +: 32]),
                .data_out_t(sb_out_t[c*32 +: 32]),
                .data_out_f(sb_out_f[c*32 +: 32])
            );
        end
    endgenerate

    shift_rows sr_inst (
        .data_in_t(sb_out_t), 
        .data_in_f(sb_out_f),
        .shifted_data_t(sr_out_t), 
        .shifted_data_f(sr_out_f)
    );

    mix_columns mc_inst (
        .data_in_t(sr_out_t), 
        .data_in_f(sr_out_f),
        .data_out_t(mc_out_t), 
        .data_out_f(mc_out_f)
    );

    add_round_key ark_inst (
        .key_t(key_t), 
        .key_f(key_f),
        .data_t(ark_in_t), 
        .data_f(ark_in_f),
        .data_out_t(data_out_t), 
        .data_out_f(data_out_f)
    );

endmodule