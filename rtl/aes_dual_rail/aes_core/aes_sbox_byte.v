// Single-byte dual-rail AES S-box.
// Exactly ONE GF block is instantiated.
module aes_sbox_byte (
    input  wire [7:0] data_in_t,
    input  wire [7:0] data_in_f,
    output wire [7:0] data_out_t,
    output wire [7:0] data_out_f
);
    wire [7:0] gf_t, gf_f;
    GF u_gf (
        .data_in_t(data_in_t), .data_in_f(data_in_f),
        .data_out_t(gf_t), .data_out_f(gf_f)
    );
    aff_trans u_aff (
        .aff_trans_in_t(gf_t), .aff_trans_in_f(gf_f),
        .aff_trans_out_t(data_out_t), .aff_trans_out_f(data_out_f)
    );
endmodule

// Single-byte dual-rail inverse AES S-box.
module aes_inv_sbox_byte (
    input  wire [7:0] data_in_t,
    input  wire [7:0] data_in_f,
    output wire [7:0] data_out_t,
    output wire [7:0] data_out_f
);
    wire [7:0] ia_t, ia_f;
    wire [7:0] gf_t, gf_f;
    inv_aff u_inv_aff (
        .inv_aff_in_t(data_in_t), .inv_aff_in_f(data_in_f),
        .inv_aff_out_t(ia_t), .inv_aff_out_f(ia_f)
    );
    GF u_gf (
        .data_in_t(ia_t), .data_in_f(ia_f),
        .data_out_t(gf_t), .data_out_f(gf_f)
    );
    assign data_out_t = gf_t;
    assign data_out_f = gf_f;
endmodule

module dr_xor8 (
    input wire [7:0] a_t, input wire [7:0] a_f,
    input wire [7:0] b_t, input wire [7:0] b_f,
    output wire [7:0] y_t, output wire [7:0] y_f
);
    genvar i;
    generate
        for (i=0;i<8;i=i+1) begin : g
            assign y_t[i] = (a_t[i] & b_f[i]) | (a_f[i] & b_t[i]);
            assign y_f[i] = (a_t[i] & b_t[i]) | (a_f[i] & b_f[i]);
        end
    endgenerate
endmodule
