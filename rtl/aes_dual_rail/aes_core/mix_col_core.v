module mix_col_core(
    input  wire [7:0] a0_t, a0_f, a1_t, a1_f, a2_t, a2_f, a3_t, a3_f,
    output wire [7:0] b0_t, b0_f, b1_t, b1_f, b2_t, b2_f, b3_t, b3_f
);

    wire [7:0] mb2a0_t, mb2a0_f, mb2a1_t, mb2a1_f, mb2a2_t, mb2a2_f, mb2a3_t, mb2a3_f;
    wire [7:0] mb3a0_t, mb3a0_f, mb3a1_t, mb3a1_f, mb3a2_t, mb3a2_f, mb3a3_t, mb3a3_f;

    assign {mb2a0_t, mb2a0_f} = dr_mb2(a0_t, a0_f);
    assign {mb2a1_t, mb2a1_f} = dr_mb2(a1_t, a1_f);
    assign {mb2a2_t, mb2a2_f} = dr_mb2(a2_t, a2_f);
    assign {mb2a3_t, mb2a3_f} = dr_mb2(a3_t, a3_f);

    assign {mb3a0_t, mb3a0_f} = dr_mb3(a0_t, a0_f);
    assign {mb3a1_t, mb3a1_f} = dr_mb3(a1_t, a1_f);
    assign {mb3a2_t, mb3a2_f} = dr_mb3(a2_t, a2_f);
    assign {mb3a3_t, mb3a3_f} = dr_mb3(a3_t, a3_f);

    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : bit_k
            // b0 = 2a0 ^ 3a1 ^ a2 ^ a3
            assign {b0_t[k], b0_f[k]} = dr_xor4(mb2a0_t[k],mb2a0_f[k], mb3a1_t[k],mb3a1_f[k], a2_t[k],a2_f[k], a3_t[k],a3_f[k]);
            // b1 = a0 ^ 2a1 ^ 3a2 ^ a3
            assign {b1_t[k], b1_f[k]} = dr_xor4(a0_t[k],a0_f[k], mb2a1_t[k],mb2a1_f[k], mb3a2_t[k],mb3a2_f[k], a3_t[k],a3_f[k]);
            // b2 = a0 ^ a1 ^ 2a2 ^ 3a3
            assign {b2_t[k], b2_f[k]} = dr_xor4(a0_t[k],a0_f[k], a1_t[k],a1_f[k], mb2a2_t[k],mb2a2_f[k], mb3a3_t[k],mb3a3_f[k]);
            // b3 = 3a0 ^ a1 ^ a2 ^ 2a3
            assign {b3_t[k], b3_f[k]} = dr_xor4(mb3a0_t[k],mb3a0_f[k], a1_t[k],a1_f[k], a2_t[k],a2_f[k], mb2a3_t[k],mb2a3_f[k]);
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

    function [15:0] dr_mb3;
        input [7:0] xt, xf;
        reg [15:0] m2;
        reg [1:0] z7,z6,z5,z4,z3,z2,z1,z0;
        begin
            m2 = dr_mb2(xt, xf);
            z7 = dr_xor2(m2[15],m2[7], xt[7],xf[7]);
            z6 = dr_xor2(m2[14],m2[6], xt[6],xf[6]);
            z5 = dr_xor2(m2[13],m2[5], xt[5],xf[5]);
            z4 = dr_xor2(m2[12],m2[4], xt[4],xf[4]);
            z3 = dr_xor2(m2[11],m2[3], xt[3],xf[3]);
            z2 = dr_xor2(m2[10],m2[2], xt[2],xf[2]);
            z1 = dr_xor2(m2[9], m2[1], xt[1],xf[1]);
            z0 = dr_xor2(m2[8], m2[0], xt[0],xf[0]);
            dr_mb3 = { z7[1],z6[1],z5[1],z4[1],z3[1],z2[1],z1[1],z0[1],
                       z7[0],z6[0],z5[0],z4[0],z3[0],z2[0],z1[0],z0[0] };
        end
    endfunction

endmodule
