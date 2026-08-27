// inv_mix_col_core: shared dual-rail InvMixColumns engine for ONE column (4 bytes in/out).
// This is the ONLY inverse-MixColumns instance in the design; the round controller
// reuses it 4 times (once per column) instead of instantiating 4 in parallel.
module inv_mix_col_core(
    input  wire [7:0] a0_t, a0_f, a1_t, a1_f, a2_t, a2_f, a3_t, a3_f,
    output wire [7:0] b0_t, b0_f, b1_t, b1_f, b2_t, b2_f, b3_t, b3_f
);

    wire [7:0] mb9a0_t, mb9a0_f, mb9a1_t, mb9a1_f, mb9a2_t, mb9a2_f, mb9a3_t, mb9a3_f;
    wire [7:0] mbBa0_t, mbBa0_f, mbBa1_t, mbBa1_f, mbBa2_t, mbBa2_f, mbBa3_t, mbBa3_f;
    wire [7:0] mbDa0_t, mbDa0_f, mbDa1_t, mbDa1_f, mbDa2_t, mbDa2_f, mbDa3_t, mbDa3_f;
    wire [7:0] mbEa0_t, mbEa0_f, mbEa1_t, mbEa1_f, mbEa2_t, mbEa2_f, mbEa3_t, mbEa3_f;

    assign {mb9a0_t, mb9a0_f} = dr_mb9(a0_t, a0_f);
    assign {mb9a1_t, mb9a1_f} = dr_mb9(a1_t, a1_f);
    assign {mb9a2_t, mb9a2_f} = dr_mb9(a2_t, a2_f);
    assign {mb9a3_t, mb9a3_f} = dr_mb9(a3_t, a3_f);

    assign {mbBa0_t, mbBa0_f} = dr_mbB(a0_t, a0_f);
    assign {mbBa1_t, mbBa1_f} = dr_mbB(a1_t, a1_f);
    assign {mbBa2_t, mbBa2_f} = dr_mbB(a2_t, a2_f);
    assign {mbBa3_t, mbBa3_f} = dr_mbB(a3_t, a3_f);

    assign {mbDa0_t, mbDa0_f} = dr_mbD(a0_t, a0_f);
    assign {mbDa1_t, mbDa1_f} = dr_mbD(a1_t, a1_f);
    assign {mbDa2_t, mbDa2_f} = dr_mbD(a2_t, a2_f);
    assign {mbDa3_t, mbDa3_f} = dr_mbD(a3_t, a3_f);

    assign {mbEa0_t, mbEa0_f} = dr_mbE(a0_t, a0_f);
    assign {mbEa1_t, mbEa1_f} = dr_mbE(a1_t, a1_f);
    assign {mbEa2_t, mbEa2_f} = dr_mbE(a2_t, a2_f);
    assign {mbEa3_t, mbEa3_f} = dr_mbE(a3_t, a3_f);

    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : bit_k
            // b0 = 0E*a0 ^ 0B*a1 ^ 0D*a2 ^ 09*a3
            assign {b0_t[k], b0_f[k]} = dr_xor4(mbEa0_t[k],mbEa0_f[k], mbBa1_t[k],mbBa1_f[k], mbDa2_t[k],mbDa2_f[k], mb9a3_t[k],mb9a3_f[k]);
            // b1 = 09*a0 ^ 0E*a1 ^ 0B*a2 ^ 0D*a3
            assign {b1_t[k], b1_f[k]} = dr_xor4(mb9a0_t[k],mb9a0_f[k], mbEa1_t[k],mbEa1_f[k], mbBa2_t[k],mbBa2_f[k], mbDa3_t[k],mbDa3_f[k]);
            // b2 = 0D*a0 ^ 09*a1 ^ 0E*a2 ^ 0B*a3
            assign {b2_t[k], b2_f[k]} = dr_xor4(mbDa0_t[k],mbDa0_f[k], mb9a1_t[k],mb9a1_f[k], mbEa2_t[k],mbEa2_f[k], mbBa3_t[k],mbBa3_f[k]);
            // b3 = 0B*a0 ^ 0D*a1 ^ 09*a2 ^ 0E*a3
            assign {b3_t[k], b3_f[k]} = dr_xor4(mbBa0_t[k],mbBa0_f[k], mbDa1_t[k],mbDa1_f[k], mb9a2_t[k],mb9a2_f[k], mbEa3_t[k],mbEa3_f[k]);
        end
    endgenerate

    function [1:0] dr_xor2;
        input xt, xf, yt, yf;
        begin
            dr_xor2[1] = (xt & yf) | (xf & yt);
            dr_xor2[0] = (xt & yt) | (xf & yf);
        end
    endfunction

    function [1:0] dr_xor4;
        input xt1, xf1, xt2, xf2, xt3, xf3, xt4, xf4;
        reg [1:0] t1, t2;
        begin
            t1 = dr_xor2(xt1, xf1, xt2, xf2);
            t2 = dr_xor2(xt3, xf3, xt4, xf4);
            dr_xor4 = dr_xor2(t1[1], t1[0], t2[1], t2[0]);
        end
    endfunction

    function [15:0] dr_xor2_vec8;
        input [7:0] xt1, xf1, xt2, xf2;
        reg [1:0] z7,z6,z5,z4,z3,z2,z1,z0;
        begin
            z7 = dr_xor2(xt1[7], xf1[7], xt2[7], xf2[7]);
            z6 = dr_xor2(xt1[6], xf1[6], xt2[6], xf2[6]);
            z5 = dr_xor2(xt1[5], xf1[5], xt2[5], xf2[5]);
            z4 = dr_xor2(xt1[4], xf1[4], xt2[4], xf2[4]);
            z3 = dr_xor2(xt1[3], xf1[3], xt2[3], xf2[3]);
            z2 = dr_xor2(xt1[2], xf1[2], xt2[2], xf2[2]);
            z1 = dr_xor2(xt1[1], xf1[1], xt2[1], xf2[1]);
            z0 = dr_xor2(xt1[0], xf1[0], xt2[0], xf2[0]);
            dr_xor2_vec8 = { z7[1],z6[1],z5[1],z4[1],z3[1],z2[1],z1[1],z0[1],
                             z7[0],z6[0],z5[0],z4[0],z3[0],z2[0],z1[0],z0[0] };
        end
    endfunction

    function [15:0] dr_xor3_vec8;
        input [7:0] xt1, xf1, xt2, xf2, xt3, xf3;
        reg [15:0] t1;
        begin
            t1 = dr_xor2_vec8(xt1, xf1, xt2, xf2);
            dr_xor3_vec8 = dr_xor2_vec8(t1[15:8], t1[7:0], xt3, xf3);
        end
    endfunction

    function [15:0] dr_mb2;
        input [7:0] xt, xf;
        reg [1:0] y4p, y3p, y1p;
        begin
            y4p = dr_xor2(xt[3],xf[3], xt[7],xf[7]);
            y3p = dr_xor2(xt[2],xf[2], xt[7],xf[7]);
            y1p = dr_xor2(xt[0],xf[0], xt[7],xf[7]);
            dr_mb2 = { xt[6],xt[5],xt[4],y4p[1],y3p[1],xt[1],y1p[1],xt[7],
                       xf[6],xf[5],xf[4],y4p[0],y3p[0],xf[1],y1p[0],xf[7] };
        end
    endfunction

    function [15:0] dr_mb4;
        input [7:0] xt, xf;
        reg [15:0] m2;
        begin
            m2 = dr_mb2(xt, xf);
            dr_mb4 = dr_mb2(m2[15:8], m2[7:0]);
        end
    endfunction

    function [15:0] dr_mb8;
        input [7:0] xt, xf;
        reg [15:0] m4;
        begin
            m4 = dr_mb4(xt, xf);
            dr_mb8 = dr_mb2(m4[15:8], m4[7:0]);
        end
    endfunction

    function [15:0] dr_mb9; // 09 = 08 ^ 01
        input [7:0] xt, xf;
        reg [15:0] m8;
        begin
            m8 = dr_mb8(xt, xf);
            dr_mb9 = dr_xor2_vec8(m8[15:8], m8[7:0], xt, xf);
        end
    endfunction

    function [15:0] dr_mbB; // 0B = 08 ^ 02 ^ 01
        input [7:0] xt, xf;
        reg [15:0] m8, m2;
        begin
            m8 = dr_mb8(xt, xf);
            m2 = dr_mb2(xt, xf);
            dr_mbB = dr_xor3_vec8(m8[15:8], m8[7:0], m2[15:8], m2[7:0], xt, xf);
        end
    endfunction

    function [15:0] dr_mbD; // 0D = 08 ^ 04 ^ 01
        input [7:0] xt, xf;
        reg [15:0] m8, m4;
        begin
            m8 = dr_mb8(xt, xf);
            m4 = dr_mb4(xt, xf);
            dr_mbD = dr_xor3_vec8(m8[15:8], m8[7:0], m4[15:8], m4[7:0], xt, xf);
        end
    endfunction

    function [15:0] dr_mbE; // 0E = 08 ^ 04 ^ 02
        input [7:0] xt, xf;
        reg [15:0] m8, m4, m2;
        begin
            m8 = dr_mb8(xt, xf);
            m4 = dr_mb4(xt, xf);
            m2 = dr_mb2(xt, xf);
            dr_mbE = dr_xor3_vec8(m8[15:8], m8[7:0], m4[15:8], m4[7:0], m2[15:8], m2[7:0]);
        end
    endfunction

endmodule
