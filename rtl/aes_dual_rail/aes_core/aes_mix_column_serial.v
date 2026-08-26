// One-column-at-a-time dual-rail MixColumns / InvMixColumns.
// The module computes only ONE AES column; the controller selects a column.
module aes_mix_column_serial (
    input  wire        decrypt,
    input  wire [31:0] in_t,
    input  wire [31:0] in_f,
    output wire [31:0] out_t,
    output wire [31:0] out_f
);
    wire [7:0] a0_t=in_t[31:24], a1_t=in_t[23:16], a2_t=in_t[15:8], a3_t=in_t[7:0];
    wire [7:0] a0_f=in_f[31:24], a1_f=in_f[23:16], a2_f=in_f[15:8], a3_f=in_f[7:0];

    function [15:0] x2;
        input [7:0] xt, xf;
        reg [1:0] z7,z6,z5,z4,z3,z2,z1,z0;
        begin
            z7 = {xt[6],xf[6]};
            z6 = {xt[5],xf[5]};
            z5 = {xt[4],xf[4]};
            z4 = dr_x2(xt[3],xf[3],xt[7],xf[7]);
            z3 = dr_x2(xt[2],xf[2],xt[7],xf[7]);
            z2 = {xt[1],xf[1]};
            z1 = dr_x2(xt[0],xf[0],xt[7],xf[7]);
            z0 = {xt[7],xf[7]};
            x2 = {z7[1],z6[1],z5[1],z4[1],z3[1],z2[1],z1[1],z0[1],
                 z7[0],z6[0],z5[0],z4[0],z3[0],z2[0],z1[0],z0[0]};
        end
    endfunction

    function [1:0] dr_x2;
        input xt,xf,yt,yf;
        begin
            dr_x2[1]=(xt&yf)|(xf&yt);
            dr_x2[0]=(xt&yt)|(xf&yf);
        end
    endfunction

    function [15:0] xv;
        input [7:0] xt,xf;
        input [3:0] c;
        reg [15:0] m2,m4,m8,r;
        begin
            m2=x2(xt,xf); m4=x2(m2[15:8],m2[7:0]); m8=x2(m4[15:8],m4[7:0]);
            case(c)
              4'h1: r={xt,xf};
              4'h2: r=m2;
              4'h3: r=dx2v(m2[15:8],m2[7:0],xt,xf);
              4'h4: r=m4;
              4'h8: r=m8;
              4'h9: r=dx2v(m8[15:8],m8[7:0],xt,xf);
              4'hb: r=dx3v(m8[15:8],m8[7:0],m2[15:8],m2[7:0],xt,xf);
              4'hd: r=dx3v(m8[15:8],m8[7:0],m4[15:8],m4[7:0],xt,xf);
              4'he: r=dx3v(m8[15:8],m8[7:0],m4[15:8],m4[7:0],m2[15:8],m2[7:0]);
              default: r=16'b0;
            endcase
            xv=r;
        end
    endfunction

    function [15:0] dx2v;
        input [7:0] x1t,x1f,x2t,x2f;
        integer j; reg [15:0] q; reg [1:0] z;
        begin
            q=0;
            for(j=0;j<8;j=j+1) begin
                z=dr_x2(x1t[j],x1f[j],x2t[j],x2f[j]);
                q[j]=z[1]; q[8+j]=z[0];
            end
            dx2v=q;
        end
    endfunction

    function [15:0] dx3v;
        input [7:0] x1t,x1f,x2t,x2f,x3t,x3f;
        reg [15:0] q;
        begin
            q=dx2v(x1t,x1f,x2t,x2f);
            dx3v=dx2v(q[15:8],q[7:0],x3t,x3f);
        end
    endfunction

    wire [15:0] p0 = xv(a0_t,a0_f, decrypt ? 4'he : 4'h2);
    wire [15:0] p1 = xv(a1_t,a1_f, decrypt ? 4'hb : 4'h3);
    wire [15:0] p2 = xv(a2_t,a2_f, decrypt ? 4'hd : 4'h1);
    wire [15:0] p3 = xv(a3_t,a3_f, decrypt ? 4'h9 : 4'h1);
    wire [15:0] q0 = xv(a0_t,a0_f, decrypt ? 4'h9 : 4'h1);
    wire [15:0] q1 = xv(a1_t,a1_f, decrypt ? 4'he : 4'h2);
    wire [15:0] q2 = xv(a2_t,a2_f, decrypt ? 4'hb : 4'h3);
    wire [15:0] q3 = xv(a3_t,a3_f, decrypt ? 4'hd : 4'h1);
    wire [15:0] r0 = xv(a0_t,a0_f, decrypt ? 4'hd : 4'h1);
    wire [15:0] r1 = xv(a1_t,a1_f, decrypt ? 4'h9 : 4'h1);
    wire [15:0] r2 = xv(a2_t,a2_f, decrypt ? 4'he : 4'h2);
    wire [15:0] r3 = xv(a3_t,a3_f, decrypt ? 4'hb : 4'h3);
    wire [15:0] s0 = xv(a0_t,a0_f, decrypt ? 4'hb : 4'h3);
    wire [15:0] s1 = xv(a1_t,a1_f, decrypt ? 4'hd : 4'h1);
    wire [15:0] s2 = xv(a2_t,a2_f, decrypt ? 4'h9 : 4'h1);
    wire [15:0] s3 = xv(a3_t,a3_f, decrypt ? 4'he : 4'h2);

    function [1:0] x2bit;
        input at,af,bt,bf;
        begin x2bit[1]=(at&bf)|(af&bt); x2bit[0]=(at&bt)|(af&bf); end
    endfunction
    function [1:0] xor2bit;
        input at,af,bt,bf;
        begin xor2bit[1]=(at&bf)|(af&bt); xor2bit[0]=(at&bt)|(af&bf); end
    endfunction
    function [1:0] xor4bit;
        input a_t,a_f,b_t,b_f,c_t,c_f,d_t,d_f;
        reg [1:0] u,v;
        begin u=xor2bit(a_t,a_f,b_t,b_f); v=xor2bit(c_t,c_f,d_t,d_f); xor4bit=xor2bit(u[1],u[0],v[1],v[0]); end
    endfunction

    genvar k;
    generate for(k=0;k<8;k=k+1) begin : g
        wire [1:0] y0=xor4bit(p0[k],p0[8+k],p1[k],p1[8+k],p2[k],p2[8+k],p3[k],p3[8+k]);
        wire [1:0] y1=xor4bit(q0[k],q0[8+k],q1[k],q1[8+k],q2[k],q2[8+k],q3[k],q3[8+k]);
        wire [1:0] y2=xor4bit(r0[k],r0[8+k],r1[k],r1[8+k],r2[k],r2[8+k],r3[k],r3[8+k]);
        wire [1:0] y3=xor4bit(s0[k],s0[8+k],s1[k],s1[8+k],s2[k],s2[8+k],s3[k],s3[8+k]);
        assign out_t[31-k]=y0[1]; assign out_f[31-k]=y0[0];
        assign out_t[23-k]=y1[1]; assign out_f[23-k]=y1[0];
        assign out_t[15-k]=y2[1]; assign out_f[15-k]=y2[0];
        assign out_t[7-k]=y3[1];  assign out_f[7-k]=y3[0];
    end endgenerate
endmodule
