// sub_byte_core: shared single-byte dual-rail SubBytes / InvSubBytes engine.
// This is the ONLY S-box instance in the whole design (1x GF + 1x aff_trans + 1x inv_aff).
// It is reused serially, one byte per cycle, by:
//   - the round datapath's SubBytes/InvSubBytes stage (16 bytes/round)
//   - the key-expansion SubWord step
// Purely combinational; the caller supplies one byte per cycle and registers the result.
module sub_byte_core(
    input  wire       en,          // 1 = forward S-box (encrypt path / key expansion SubWord)
    input  wire       de,          // 1 = inverse S-box (decrypt path)
    input  wire [7:0] data_in_t,
    input  wire [7:0] data_in_f,

    output wire [7:0] data_out_t,
    output wire [7:0] data_out_f
);

    wire [7:0] inv_aff_out_t, inv_aff_out_f;
    wire [7:0] gf_in_t, gf_in_f;
    wire [7:0] gf_out_t, gf_out_f;
    wire [7:0] aff_out_t, aff_out_f;

    // Decryption path: InvAffine first, then GF inverse
    inv_aff inv_aff_0(
        .inv_aff_in_t (data_in_t),
        .inv_aff_in_f (data_in_f),
        .inv_aff_out_t(inv_aff_out_t),
        .inv_aff_out_f(inv_aff_out_f)
    );

    // Encryption path feeds data straight into GF; decryption feeds InvAffine's output
    assign gf_in_t = en ? data_in_t : inv_aff_out_t;
    assign gf_in_f = en ? data_in_f : inv_aff_out_f;

    GF gf_0(
        .data_in_t (gf_in_t),
        .data_in_f (gf_in_f),
        .data_out_t(gf_out_t),
        .data_out_f(gf_out_f)
    );

    // Encryption path: GF inverse, then Affine transform
    aff_trans aff_trans_0(
        .aff_trans_in_t(gf_out_t),
        .aff_trans_in_f(gf_out_f),
        .aff_trans_out_t(aff_out_t),
        .aff_trans_out_f(aff_out_f)
    );

    assign data_out_t = de ? gf_out_t : aff_out_t;
    assign data_out_f = de ? gf_out_f : aff_out_f;

endmodule
