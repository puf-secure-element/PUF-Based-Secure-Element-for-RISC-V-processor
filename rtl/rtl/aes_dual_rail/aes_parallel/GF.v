module GF(
    input  wire [7:0] data_in_t,
    input  wire [7:0] data_in_f,

    output wire [7:0] data_out_t,
    output wire [7:0] data_out_f
);

    wire [3:0] ah_t, ah_f, al_t, al_f;
    wire [3:0] ah_sq_lam_t, ah_sq_lam_f;
    wire [3:0] al_sq_t, al_sq_f;
    wire [3:0] ah_mul_al_t, ah_mul_al_f;
    wire [3:0] d_t, d_f, d_inv_t, d_inv_f;
    wire [3:0] ah_out_t, ah_out_f, al_out_t, al_out_f;
    wire [3:0] ah_xor_al_t, ah_xor_al_f;
 
    assign {ah_t[3], ah_f[3]} = dr_xor2(data_in_t[5], data_in_f[5], data_in_t[7], data_in_f[7]);
    assign {ah_t[2], ah_f[2]} = dr_xor4(data_in_t[2], data_in_f[2], data_in_t[3], data_in_f[3], data_in_t[5], data_in_f[5], data_in_t[7], data_in_f[7]);
    assign {ah_t[1], ah_f[1]} = dr_xor4(data_in_t[1], data_in_f[1], data_in_t[4], data_in_f[4], data_in_t[6], data_in_f[6], data_in_t[7], data_in_f[7]);
    assign {ah_t[0], ah_f[0]} = dr_xor3(data_in_t[4], data_in_f[4], data_in_t[5], data_in_f[5], data_in_t[6], data_in_f[6]);
 
    assign {al_t[3], al_f[3]} = dr_xor2(data_in_t[3], data_in_f[3], data_in_t[4], data_in_f[4]);
    assign {al_t[2], al_f[2]} = dr_xor6(data_in_t[2], data_in_f[2], data_in_t[3], data_in_f[3], data_in_t[4], data_in_f[4], data_in_t[5], data_in_f[5], data_in_t[6], data_in_f[6], data_in_t[7], data_in_f[7]);
    assign {al_t[1], al_f[1]} = {data_in_t[2], data_in_f[2]};
    assign {al_t[0], al_f[0]} = dr_xor3(data_in_t[0], data_in_f[0], data_in_t[5], data_in_f[5], data_in_t[7], data_in_f[7]);

    assign {ah_sq_lam_t, ah_sq_lam_f} = gf4_sq_scale_dr(ah_t, ah_f);
    assign {al_sq_t, al_sq_f}         = gf4_sq_dr(al_t, al_f);
    assign {ah_mul_al_t, ah_mul_al_f} = gf4_mul_dr(ah_t, ah_f, al_t, al_f);
 
    assign {d_t[3], d_f[3]} = dr_xor3(ah_sq_lam_t[3], ah_sq_lam_f[3], ah_mul_al_t[3], ah_mul_al_f[3], al_sq_t[3], al_sq_f[3]);
    assign {d_t[2], d_f[2]} = dr_xor3(ah_sq_lam_t[2], ah_sq_lam_f[2], ah_mul_al_t[2], ah_mul_al_f[2], al_sq_t[2], al_sq_f[2]);
    assign {d_t[1], d_f[1]} = dr_xor3(ah_sq_lam_t[1], ah_sq_lam_f[1], ah_mul_al_t[1], ah_mul_al_f[1], al_sq_t[1], al_sq_f[1]);
    assign {d_t[0], d_f[0]} = dr_xor3(ah_sq_lam_t[0], ah_sq_lam_f[0], ah_mul_al_t[0], ah_mul_al_f[0], al_sq_t[0], al_sq_f[0]);
 
    assign {d_inv_t, d_inv_f} = gf4_inv_dr(d_t, d_f);
 
    assign {ah_out_t, ah_out_f} = gf4_mul_dr(ah_t, ah_f, d_inv_t, d_inv_f);
 
    assign {ah_xor_al_t[3], ah_xor_al_f[3]} = dr_xor2(ah_t[3], ah_f[3], al_t[3], al_f[3]);
    assign {ah_xor_al_t[2], ah_xor_al_f[2]} = dr_xor2(ah_t[2], ah_f[2], al_t[2], al_f[2]);
    assign {ah_xor_al_t[1], ah_xor_al_f[1]} = dr_xor2(ah_t[1], ah_f[1], al_t[1], al_f[1]);
    assign {ah_xor_al_t[0], ah_xor_al_f[0]} = dr_xor2(ah_t[0], ah_f[0], al_t[0], al_f[0]);
    assign {al_out_t, al_out_f} = gf4_mul_dr(ah_xor_al_t, ah_xor_al_f, d_inv_t, d_inv_f);
 
    assign {data_out_t[0], data_out_f[0]} = dr_xor2(ah_out_t[3], ah_out_f[3], al_out_t[0], al_out_f[0]);
    assign {data_out_t[1], data_out_f[1]} = dr_xor3(ah_out_t[3], ah_out_f[3], ah_out_t[1], ah_out_f[1], ah_out_t[0], ah_out_f[0]);
    assign {data_out_t[2], data_out_f[2]} = {al_out_t[1], al_out_f[1]};
    assign {data_out_t[3], data_out_f[3]} = dr_xor3(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], al_out_t[1], al_out_f[1]);
    assign {data_out_t[4], data_out_f[4]} = dr_xor4(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], al_out_t[3], al_out_f[3], al_out_t[1], al_out_f[1]);
    assign {data_out_t[5], data_out_f[5]} = dr_xor3(ah_out_t[2], ah_out_f[2], ah_out_t[0], ah_out_f[0], al_out_t[2], al_out_f[2]);
    assign {data_out_t[6], data_out_f[6]} = dr_xor4(ah_out_t[3], ah_out_f[3], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2], al_out_t[1], al_out_f[1]);
    assign {data_out_t[7], data_out_f[7]} = dr_xor4(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[0], ah_out_f[0], al_out_t[2], al_out_f[2]);
 
 
    function [1:0] dr_and;
        input xt, xf, yt, yf;
        begin
            dr_and[1] = xt & yt;
            dr_and[0] = xf | yf;
        end
    endfunction
 
    function [1:0] dr_or;
        input xt, xf, yt, yf;
        begin
            dr_or[1] = xt | yt;
            dr_or[0] = xf & yf;
        end
    endfunction
 
    function [1:0] dr_not;
        input xt, xf;
        begin
            dr_not[1] = xf;
            dr_not[0] = xt;
        end
    endfunction
 
    function [1:0] dr_xor2;
        input xt, xf, yt, yf;
        begin
            dr_xor2[1] = (xt & yf) | (xf & yt);
            dr_xor2[0] = (xt & yt) | (xf & yf);
        end
    endfunction
 
    function [1:0] dr_xor3;
        input xt1, xf1, xt2, xf2, xt3, xf3;
        reg [1:0] t1;
        begin
            t1 = dr_xor2(xt1, xf1, xt2, xf2);
            dr_xor3 = dr_xor2(t1[1], t1[0], xt3, xf3);
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
 
    function [1:0] dr_xor5;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4, xt5,xf5;
        reg [1:0] t1;
        begin
            t1 = dr_xor4(xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4);
            dr_xor5 = dr_xor2(t1[1], t1[0], xt5, xf5);
        end
    endfunction
 
    function [1:0] dr_xor6;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4, xt5,xf5, xt6,xf6;
        reg [1:0] t1, t2;
        begin
            t1 = dr_xor4(xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4);
            t2 = dr_xor2(xt5,xf5, xt6,xf6);
            dr_xor6 = dr_xor2(t1[1], t1[0], t2[1], t2[0]);
        end
    endfunction
 
    function [1:0] dr_xor7;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4, xt5,xf5, xt6,xf6, xt7,xf7;
        reg [1:0] t1, t2;
        begin
            t1 = dr_xor4(xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4);
            t2 = dr_xor3(xt5,xf5, xt6,xf6, xt7,xf7);
            dr_xor7 = dr_xor2(t1[1], t1[0], t2[1], t2[0]);
        end
    endfunction
 
    function [1:0] dr_or3;
        input xt1,xf1, xt2,xf2, xt3,xf3;
        reg [1:0] t1;
        begin
            t1 = dr_or(xt1,xf1, xt2,xf2);
            dr_or3 = dr_or(t1[1], t1[0], xt3, xf3);
        end
    endfunction
 
    function [1:0] dr_or4;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4;
        reg [1:0] t1, t2;
        begin
            t1 = dr_or(xt1,xf1, xt2,xf2);
            t2 = dr_or(xt3,xf3, xt4,xf4);
            dr_or4 = dr_or(t1[1], t1[0], t2[1], t2[0]);
        end
    endfunction
 
    function [1:0] dr_or5;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4, xt5,xf5;
        reg [1:0] t1;
        begin
            t1 = dr_or4(xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4);
            dr_or5 = dr_or(t1[1], t1[0], xt5, xf5);
        end
    endfunction
 
    function [1:0] dr_or6;
        input xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4, xt5,xf5, xt6,xf6;
        reg [1:0] t1, t2;
        begin
            t1 = dr_or4(xt1,xf1, xt2,xf2, xt3,xf3, xt4,xf4);
            t2 = dr_or(xt5,xf5, xt6,xf6);
            dr_or6 = dr_or(t1[1], t1[0], t2[1], t2[0]);
        end
    endfunction
 
    function [7:0] gf4_mul_dr;
        input [3:0] xt, xf;
        input [3:0] yt, yf;
        reg [1:0] a[0:3][0:3];
        reg [1:0] p_t[0:3];
        reg [1:0] res_t[0:3];
        begin
            a[0][0]=dr_and(xt[0],xf[0], yt[0],yf[0]); a[0][1]=dr_and(xt[0],xf[0], yt[1],yf[1]); a[0][2]=dr_and(xt[0],xf[0], yt[2],yf[2]); a[0][3]=dr_and(xt[0],xf[0], yt[3],yf[3]);
            a[1][0]=dr_and(xt[1],xf[1], yt[0],yf[0]); a[1][1]=dr_and(xt[1],xf[1], yt[1],yf[1]); a[1][2]=dr_and(xt[1],xf[1], yt[2],yf[2]); a[1][3]=dr_and(xt[1],xf[1], yt[3],yf[3]);
            a[2][0]=dr_and(xt[2],xf[2], yt[0],yf[0]); a[2][1]=dr_and(xt[2],xf[2], yt[1],yf[1]); a[2][2]=dr_and(xt[2],xf[2], yt[2],yf[2]); a[2][3]=dr_and(xt[2],xf[2], yt[3],yf[3]);
            a[3][0]=dr_and(xt[3],xf[3], yt[0],yf[0]); a[3][1]=dr_and(xt[3],xf[3], yt[1],yf[1]); a[3][2]=dr_and(xt[3],xf[3], yt[2],yf[2]); a[3][3]=dr_and(xt[3],xf[3], yt[3],yf[3]);
 
            p_t[3] = dr_xor4(a[0][3][1],a[0][3][0], a[1][2][1],a[1][2][0], a[2][1][1],a[2][1][0], a[3][0][1],a[3][0][0]); // z3
            p_t[2] = dr_xor3(a[1][3][1],a[1][3][0], a[2][2][1],a[2][2][0], a[3][1][1],a[3][1][0]);                       // z4
            p_t[1] = dr_xor2(a[2][3][1],a[2][3][0], a[3][2][1],a[3][2][0]);                                              // z5
            p_t[0] = a[3][3];                                                                                            // z6
 
            res_t[3] = dr_xor2(p_t[3][1],p_t[3][0], p_t[0][1],p_t[0][0]);                                                 // z3^z6
            res_t[2] = dr_xor5(a[0][2][1],a[0][2][0], a[1][1][1],a[1][1][0], a[2][0][1],a[2][0][0], p_t[1][1],p_t[1][0], p_t[0][1],p_t[0][0]); // z2^z5^z6
            res_t[1] = dr_xor4(a[0][1][1],a[0][1][0], a[1][0][1],a[1][0][0], p_t[2][1],p_t[2][0], p_t[1][1],p_t[1][0]);   // z1^z4^z5  (đã bỏ p_t[3],p_t[0])
            res_t[0] = dr_xor2(a[0][0][1],a[0][0][0], p_t[2][1],p_t[2][0]);                                              // z0^z4     (đã bỏ p_t[1],p_t[0])
 
            gf4_mul_dr = {res_t[3][1],res_t[2][1],res_t[1][1],res_t[0][1],
                          res_t[3][0],res_t[2][0],res_t[1][0],res_t[0][0]};
        end
    endfunction
 
    function [7:0] gf4_sq_dr;
        input [3:0] xt, xf;
        reg [1:0] b2p, b0p;
        begin
            b2p = dr_xor2(xt[3], xf[3], xt[1], xf[1]);
            b0p = dr_xor2(xt[2], xf[2], xt[0], xf[0]);
            gf4_sq_dr = {xt[3], b2p[1], xt[2], b0p[1],
                         xf[3], b2p[0], xf[2], b0p[0]};
        end
    endfunction
 
    function [7:0] gf4_sq_scale_dr;
        input [3:0] xt, xf;
        reg [7:0] sq;
        begin
            sq = gf4_sq_dr(xt, xf);
            gf4_sq_scale_dr = gf4_mul_dr(sq[7:4], sq[3:0], 4'b1000, 4'b0111);
        end
    endfunction

    function [7:0] gf4_inv_dr;
        input [3:0] xt, xf;
        reg [1:0] nx3, nx2, nx1, nx0;      // not(x3), not(x2), not(x1), not(x0)
        reg [1:0] x01, x02, x03, x12, x13, x23; // pairwise ANDs of true vars
        reg [1:0] n2n3, n1n3, n0n1, n0n2, n1n2, n0n3; // pairwise ANDs of negated vars
        reg [1:0] x012, x013, x023, x123;   // triple ANDs of true vars
        reg [1:0] t1,t2,t3,t4,t5,t6;
        reg [1:0] n3,n2,n1,n0;
        begin
            nx3 = dr_not(xt[3], xf[3]);
            nx2 = dr_not(xt[2], xf[2]);
            nx1 = dr_not(xt[1], xf[1]);
            nx0 = dr_not(xt[0], xf[0]);
 
            x01 = dr_and(xt[0],xf[0], xt[1],xf[1]);
            x02 = dr_and(xt[0],xf[0], xt[2],xf[2]);
            x03 = dr_and(xt[0],xf[0], xt[3],xf[3]);
            x12 = dr_and(xt[1],xf[1], xt[2],xf[2]);
            x13 = dr_and(xt[1],xf[1], xt[3],xf[3]);
            x23 = dr_and(xt[2],xf[2], xt[3],xf[3]);
 
            n2n3 = dr_and(nx2[1],nx2[0], nx3[1],nx3[0]);
            n1n3 = dr_and(nx1[1],nx1[0], nx3[1],nx3[0]);
            n0n1 = dr_and(nx0[1],nx0[0], nx1[1],nx1[0]);
            n0n2 = dr_and(nx0[1],nx0[0], nx2[1],nx2[0]);
            n1n2 = dr_and(nx1[1],nx1[0], nx2[1],nx2[0]);
            n0n3 = dr_and(nx0[1],nx0[0], nx3[1],nx3[0]);
 
            x012 = dr_and(x01[1],x01[0], xt[2],xf[2]);
            x013 = dr_and(x01[1],x01[0], xt[3],xf[3]);
            x023 = dr_and(x02[1],x02[0], xt[3],xf[3]);
            x123 = dr_and(x12[1],x12[0], xt[3],xf[3]);
 
            t1 = x012; t1 = dr_and(t1[1],t1[0], xt[3],xf[3]); // x0x1x2x3
            t2 = dr_and(xt[1],xf[1], n2n3[1],n2n3[0]);
            t3 = dr_and(xt[2],xf[2], n1n3[1],n1n3[0]);
            t4 = dr_and(xt[3],xf[3], n0n1[1],n0n1[0]);
            t5 = dr_and(xt[3],xf[3], n0n2[1],n0n2[0]);
            n3 = dr_or5(t1[1],t1[0], t2[1],t2[0], t3[1],t3[0], t4[1],t4[0], t5[1],t5[0]);
 
            t1 = dr_and(x01[1],x01[0], nx2[1],nx2[0]);
            t2 = dr_and(x01[1],x01[0], nx3[1],nx3[0]);
            t3 = dr_and(xt[2],xf[2], n0n3[1],n0n3[0]);
            t4 = dr_and(xt[3],xf[3], n0n2[1],n0n2[0]);
            t5 = dr_and(x023[1],x023[0], nx1[1],nx1[0]);
            n2 = dr_or5(t1[1],t1[0], t2[1],t2[0], t3[1],t3[0], t4[1],t4[0], t5[1],t5[0]);
 
            t1 = dr_and(x01[1],x01[0], nx3[1],nx3[0]);
            t2 = dr_and(x02[1],x02[0], nx3[1],nx3[0]);
            t3 = dr_and(x12[1],x12[0], nx0[1],nx0[0]);
            t4 = dr_and(x23[1],x23[0], nx0[1],nx0[0]);
            t5 = dr_and(xt[3],xf[3], n1n2[1],n1n2[0]);
            n1 = dr_or5(t1[1],t1[0], t2[1],t2[0], t3[1],t3[0], t4[1],t4[0], t5[1],t5[0]);
 
            t1 = dr_and(x12[1],x12[0], nx0[1],nx0[0]);
            t2 = dr_and(xt[0],xf[0], n1n3[1],n1n3[0]);
            t3 = dr_and(xt[1],xf[1], n0n3[1],n0n3[0]);
            t4 = dr_and(xt[2],xf[2], n0n3[1],n0n3[0]);
            t5 = dr_and(x013[1],x013[0], nx2[1],nx2[0]);
            t6 = dr_and(nx0[1],nx0[0], n1n2[1],n1n2[0]);
            t6 = dr_and(xt[3],xf[3], t6[1],t6[0]);
            n0 = dr_or6(t1[1],t1[0], t2[1],t2[0], t3[1],t3[0], t4[1],t4[0], t5[1],t5[0], t6[1],t6[0]);
 
            gf4_inv_dr = {n3[1],n2[1],n1[1],n0[1], n3[0],n2[0],n1[0],n0[0]};
        end
    endfunction

endmodule