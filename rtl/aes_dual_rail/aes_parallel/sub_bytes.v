module sub_bytes(
    input wire              en,    //Encryption enable
    input wire              de,    //Decryption enable
    input wire  [31:0]      data_in_t,
    input wire  [31:0]      data_in_f,

    output wire [31:0]      data_out_t,
    output wire [31:0]      data_out_f
);

    wire [7:0] data_t_0, data_t_1, data_t_2, data_t_3;
    wire [7:0] data_f_0, data_f_1, data_f_2, data_f_3;
    //Data out of GF and affine transformation
    wire [7:0] aff_out_t_0, aff_out_t_1, aff_out_t_2, aff_out_t_3;
    wire [7:0] aff_out_f_0, aff_out_f_1, aff_out_f_2, aff_out_f_3;
    //Data out of GF and inverse affine transformation
    wire [7:0] inv_aff_out_t_0, inv_aff_out_t_1, inv_aff_out_t_2, inv_aff_out_t_3;
    wire [7:0] inv_aff_out_f_0, inv_aff_out_f_1, inv_aff_out_f_2, inv_aff_out_f_3;
    //Data in and out of GF
    wire [7:0] GF_in_t_0, GF_in_t_1, GF_in_t_2, GF_in_t_3;
    wire [7:0] GF_in_f_0, GF_in_f_1, GF_in_f_2, GF_in_f_3;

    wire [7:0] GF_out_t_0, GF_out_t_1, GF_out_t_2, GF_out_t_3;
    wire [7:0] GF_out_f_0, GF_out_f_1, GF_out_f_2, GF_out_f_3;
    
    //True data
    assign data_t_3 = data_in_t[31:24];
    assign data_t_2 = data_in_t[23:16];
    assign data_t_1 = data_in_t[15:8];
    assign data_t_0 = data_in_t[7:0];
    //False data
    assign data_f_3 = data_in_f[31:24];
    assign data_f_2 = data_in_f[23:16];
    assign data_f_1 = data_in_f[15:8];
    assign data_f_0 = data_in_f[7:0];

    GF dual_gf_0(
        .data_in_t (GF_in_t_0),
        .data_in_f (GF_in_f_0),

        .data_out_t(GF_out_t_0),
        .data_out_f(GF_out_f_0)
    );

    GF dual_gf_1(
        .data_in_t (GF_in_t_1),
        .data_in_f (GF_in_f_1),
        
        .data_out_t(GF_out_t_1),
        .data_out_f(GF_out_f_1)
    );

    GF dual_gf_2(
        .data_in_t (GF_in_t_2),
        .data_in_f (GF_in_f_2),
        
        .data_out_t(GF_out_t_2),
        .data_out_f(GF_out_f_2)
    );

    GF dual_gf_3(
        .data_in_t (GF_in_t_3),
        .data_in_f (GF_in_f_3),
        
        .data_out_t(GF_out_t_3),
        .data_out_f(GF_out_f_3)
    );

    //For Encryption
    //Data goes to GF first, then to Affine Transformation
    aff_trans aff_trans_0(
        .aff_trans_in_t(GF_out_t_0),
        .aff_trans_in_f(GF_out_f_0),

        .aff_trans_out_t(aff_out_t_0),
        .aff_trans_out_f(aff_out_f_0)
    );

    aff_trans aff_trans_1(
        .aff_trans_in_t(GF_out_t_1),
        .aff_trans_in_f(GF_out_f_1),

        .aff_trans_out_t(aff_out_t_1),
        .aff_trans_out_f(aff_out_f_1)
    );

    aff_trans aff_trans_2(
        .aff_trans_in_t(GF_out_t_2),
        .aff_trans_in_f(GF_out_f_2),

        .aff_trans_out_t(aff_out_t_2),
        .aff_trans_out_f(aff_out_f_2)
    );

    aff_trans aff_trans_3(
        .aff_trans_in_t(GF_out_t_3),
        .aff_trans_in_f(GF_out_f_3),

        .aff_trans_out_t(aff_out_t_3),
        .aff_trans_out_f(aff_out_f_3)
    );

    //For Decryption
    //Data goes to Inverse Affine Transformation first, then to GF

    inv_aff inv_aff_0(
        .inv_aff_in_t(data_t_0),
        .inv_aff_in_f(data_f_0),

        .inv_aff_out_t(inv_aff_out_t_0),
        .inv_aff_out_f(inv_aff_out_f_0)
    );

    inv_aff inv_aff_1(
        .inv_aff_in_t(data_t_1),
        .inv_aff_in_f(data_f_1),

        .inv_aff_out_t(inv_aff_out_t_1),
        .inv_aff_out_f(inv_aff_out_f_1)
    );

    inv_aff inv_aff_2(
        .inv_aff_in_t(data_t_2),
        .inv_aff_in_f(data_f_2),

        .inv_aff_out_t(inv_aff_out_t_2),
        .inv_aff_out_f(inv_aff_out_f_2)
    );

    inv_aff inv_aff_3(
        .inv_aff_in_t(data_t_3),
        .inv_aff_in_f(data_f_3),

        .inv_aff_out_t(inv_aff_out_t_3),
        .inv_aff_out_f(inv_aff_out_f_3)
    );

    //Using Mux to define Encryption and Decryption
    assign GF_in_t_0 = (en) ? data_t_0 : inv_aff_out_t_0;
    assign GF_in_t_1 = (en) ? data_t_1 : inv_aff_out_t_1;
    assign GF_in_t_2 = (en) ? data_t_2 : inv_aff_out_t_2;
    assign GF_in_t_3 = (en) ? data_t_3 : inv_aff_out_t_3;

    assign GF_in_f_0 = (en) ? data_f_0 : inv_aff_out_f_0;
    assign GF_in_f_1 = (en) ? data_f_1 : inv_aff_out_f_1;
    assign GF_in_f_2 = (en) ? data_f_2 : inv_aff_out_f_2;
    assign GF_in_f_3 = (en) ? data_f_3 : inv_aff_out_f_3;

    //If decryption, take value of GF
    assign data_out_t[31:24]    = (de) ? GF_out_t_3 : aff_out_t_3;
    assign data_out_t[23:16]    = (de) ? GF_out_t_2 : aff_out_t_2;
    assign data_out_t[15:8]     = (de) ? GF_out_t_1 : aff_out_t_1;
    assign data_out_t[7:0]      = (de) ? GF_out_t_0 : aff_out_t_0;

    assign data_out_f[31:24]    = (de) ? GF_out_f_3 : aff_out_f_3;
    assign data_out_f[23:16]    = (de) ? GF_out_f_2 : aff_out_f_2;
    assign data_out_f[15:8]     = (de) ? GF_out_f_1 : aff_out_f_1;
    assign data_out_f[7:0]      = (de) ? GF_out_f_0 : aff_out_f_0;
endmodule