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

    assign {ah_t[3], ah_f[3]} = dr_xor2(data_in_t[7], data_in_f[7], data_in_t[5], data_in_f[5]);
    assign {ah_t[2], ah_f[2]} = dr_xor6(data_in_t[7], data_in_f[7], data_in_t[6], data_in_f[6], data_in_t[4], data_in_f[4], data_in_t[3], data_in_f[3], data_in_t[2], data_in_f[2], data_in_t[1], data_in_f[1]);
    assign {ah_t[1], ah_f[1]} = dr_xor4(data_in_t[7], data_in_f[7], data_in_t[5], data_in_f[5], data_in_t[3], data_in_f[3], data_in_t[2], data_in_f[2]);
    assign {ah_t[0], ah_f[0]} = dr_xor5(data_in_t[7], data_in_f[7], data_in_t[5], data_in_f[5], data_in_t[3], data_in_f[3], data_in_t[2], data_in_f[2], data_in_t[1], data_in_f[1]);

    assign {al_t[3], al_f[3]} = dr_xor5(data_in_t[7], data_in_f[7], data_in_t[6], data_in_f[6], data_in_t[5], data_in_f[5], data_in_t[4], data_in_f[4], data_in_t[0], data_in_f[0]);
    assign {al_t[2], al_f[2]} = dr_xor2(data_in_t[6], data_in_f[6], data_in_t[5], data_in_f[5]);
    assign {al_t[1], al_f[1]} = dr_xor3(data_in_t[6], data_in_f[6], data_in_t[5], data_in_f[5], data_in_t[1], data_in_f[1]);
    assign {al_t[0], al_f[0]} = dr_xor2(data_in_t[4], data_in_f[4], data_in_t[0], data_in_f[0]);

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

    assign {data_out_t[7], data_out_f[7]} = dr_xor4(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], al_out_t[3], al_out_f[3]);
    assign {data_out_t[6], data_out_f[6]} = dr_xor5(ah_out_t[2], ah_out_f[2], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2], al_out_t[1], al_out_f[1], al_out_t[0], al_out_f[0]);
    assign {data_out_t[5], data_out_f[5]} = dr_xor5(ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2], al_out_t[1], al_out_f[1]);
    assign {data_out_t[4], data_out_f[4]} = dr_xor7(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], ah_out_t[0], ah_out_f[0], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2], al_out_t[0], al_out_f[0]);
    assign {data_out_t[3], data_out_f[3]} = dr_xor5(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], al_out_t[2], al_out_f[2], al_out_t[0], al_out_f[0]);
    assign {data_out_t[2], data_out_f[2]} = dr_xor6(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], ah_out_t[0], ah_out_f[0], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2]);
    assign {data_out_t[1], data_out_f[1]} = dr_xor3(ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], al_out_t[2], al_out_f[2]);
    assign {data_out_t[0], data_out_f[0]} = dr_xor7(ah_out_t[3], ah_out_f[3], ah_out_t[2], ah_out_f[2], ah_out_t[1], ah_out_f[1], ah_out_t[0], ah_out_f[0], al_out_t[3], al_out_f[3], al_out_t[2], al_out_f[2], al_out_t[1], al_out_f[1]);


    function [1:0] dr_and;
        input xt, xf, yt, yf;
        begin
            dr_and[1] = xt & yt;         // True rail
            dr_and[0] = xf | yf;         // False rail
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
        reg [1:0] t1, t2;
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

    function [7:0] gf4_mul_dr;
        input   [3:0]   xt, xf;
        input   [3:0]   yt, yf;

        reg     [1:0]   a[0:3][0:3];
        reg     [1:0]   p_t[0:3];
        reg     [1:0]   res_t[0:3];
        begin
            a[0][0]=dr_and(xt[0],xf[0], yt[0],yf[0]); a[0][1]=dr_and(xt[0],xf[0], yt[1],yf[1]); a[0][2]=dr_and(xt[0],xf[0], yt[2],yf[2]); a[0][3]=dr_and(xt[0],xf[0], yt[3],yf[3]);
            a[1][0]=dr_and(xt[1],xf[1], yt[0],yf[0]); a[1][1]=dr_and(xt[1],xf[1], yt[1],yf[1]); a[1][2]=dr_and(xt[1],xf[1], yt[2],yf[2]); a[1][3]=dr_and(xt[1],xf[1], yt[3],yf[3]);
            a[2][0]=dr_and(xt[2],xf[2], yt[0],yf[0]); a[2][1]=dr_and(xt[2],xf[2], yt[1],yf[1]); a[2][2]=dr_and(xt[2],xf[2], yt[2],yf[2]); a[2][3]=dr_and(xt[2],xf[2], yt[3],yf[3]);
            a[3][0]=dr_and(xt[3],xf[3], yt[0],yf[0]); a[3][1]=dr_and(xt[3],xf[3], yt[1],yf[1]); a[3][2]=dr_and(xt[3],xf[3], yt[2],yf[2]); a[3][3]=dr_and(xt[3],xf[3], yt[3],yf[3]);

            p_t[3] = dr_xor4(a[0][3][1],a[0][3][0], a[1][2][1],a[1][2][0], a[2][1][1],a[2][1][0], a[3][0][1],a[3][0][0]);
            p_t[2] = dr_xor3(a[1][3][1],a[1][3][0], a[2][2][1],a[2][2][0], a[3][1][1],a[3][1][0]);
            p_t[1] = dr_xor2(a[2][3][1],a[2][3][0], a[3][2][1],a[3][2][0]);
            p_t[0] = a[3][3];

            res_t[3] = dr_xor2(p_t[3][1],p_t[3][0], p_t[0][1],p_t[0][0]);
            res_t[2] = dr_xor5(a[0][2][1],a[0][2][0], a[1][1][1],a[1][1][0], a[2][0][1],a[2][0][0], p_t[1][1],p_t[1][0], p_t[0][1],p_t[0][0]);
            res_t[1] = dr_xor4(a[0][1][1],a[0][1][0], a[1][0][1],a[1][0][0], p_t[2][1],p_t[2][0], p_t[1][1],p_t[1][0]);
            res_t[0] = dr_xor2(a[0][0][1],a[0][0][0], p_t[2][1],p_t[2][0]);

            gf4_mul_dr = {res_t[3], res_t[2], res_t[1], res_t[0]};
        end
    endfunction

    function [7:0] gf4_sq_dr;
        input   [3:0]   xt, xf;
        begin
            gf4_sq_dr[7:6] = {xt[3], xf[3]};
            gf4_sq_dr[5:4] = dr_xor2(xt[3], xf[3], xt[1], xf[1]);
            gf4_sq_dr[3:2] = {xt[2], xf[2]};
            gf4_sq_dr[1:0] = dr_xor2(xt[2], xf[2], xt[0], xf[0]);
        end
    endfunction

    function [7:0] gf4_sq_scale_dr;
        input   [3:0]   xt, xf;
        begin
            gf4_sq_scale_dr[7:6] = {xt[2], xf[2]};
            gf4_sq_scale_dr[5:4] = dr_xor3(xt[3], xf[3], xt[2], xf[2], xt[0], xf[0]);
            gf4_sq_scale_dr[3:2] = {xt[3], xf[3]};
            gf4_sq_scale_dr[1:0] = dr_xor2(xt[3], xf[3], xt[1], xf[1]);
        end
    endfunction

    function [7:0] gf4_inv_dr;
        input   [3:0]   xt, xf;
        
        reg     [1:0]   n3, n2, n1, n0;
        reg     [1:0]   w1, w2, w3;
        begin
            w1 = dr_xor2(xt[3], xf[3], xt[2], xf[2]);
            w2 = dr_and(xt[3], xf[3], xt[1], xf[1]);
            w3 = dr_and(xt[2], xf[2], xt[1], xf[1]); 

            n3 = dr_xor5(dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[1],xf[1]))[1], dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[1],xf[1]))[0],
                         dr_and(xt[3],xf[3],xt[0],xf[0])[1], dr_and(xt[3],xf[3],xt[0],xf[0])[0],
                         dr_and(xt[2],xf[2],xt[0],xf[0])[1], dr_and(xt[2],xf[2],xt[0],xf[0])[0],
                         w2[1], w2[0], xt[3], xf[3]);

            n2 = dr_xor5(dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[1],xf[1]))[1], dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[1],xf[1]))[0],
                         dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[0],xf[0]))[1], dr_and(xt[3],xf[3],dr_and(xt[2],xf[2],xt[0],xf[0]))[0],
                         dr_and(w1[1],w1[0],xt[1],xf[1])[1], dr_and(w1[1],w1[0],xt[1],xf[1])[0],
                         dr_and(xt[2],xf[2],xt[0],xf[0])[1], dr_and(xt[2],xf[2],xt[0],xf[0])[0], xt[2], xf[2]);

            n1 = dr_xor4(dr_and(xt[3],xf[3],dr_and((xt[2]|xt[1]),(xf[2]&xf[1]),xt[0],xf[0]))[1], dr_and(xt[3],xf[3],dr_and((xt[2]|xt[1]),(xf[2]&xf[1]),xt[0],xf[0]))[0],
                         dr_and(xt[2],xf[2],dr_and(xt[1],xf[1],xt[0],xf[0]))[1], dr_and(xt[2],xf[2],dr_and(xt[1],xf[1],xt[0],xf[0]))[0],
                         w2[1], w2[0], xt[1], xf[1]);

            n0 = dr_xor6(dr_and(w1[1],w1[0],dr_and((xt[1]|xt[0]),(xf[1]&xf[0]),xt[0],xf[0]))[1], dr_and(w1[1],w1[0],dr_and((xt[1]|xt[0]),(xf[1]&xf[0]),xt[0],xf[0]))[0],
                         dr_and(xt[3],xf[3],xt[2],xf[2])[1], dr_and(xt[3],xf[3],xt[2],xf[2])[0],
                         dr_and(xt[1],xf[1],xt[0],xf[0])[1], dr_and(xt[1],xf[1],xt[0],xf[0])[0],
                         w1[1], w1[0], xt[1], xf[1], xt[0], xf[0]);

            gf4_inv_dr = {n3, n2, n1, n0};
        end
    endfunction

endmodule