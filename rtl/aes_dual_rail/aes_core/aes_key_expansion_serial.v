// AES-256 sequential key expansion.
// One S-box is reused for one byte per clock.
module aes_key_expansion_serial (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] key_in,
    input  wire [3:0]   round_sel,
    output reg          busy,
    output reg          done,
    output wire [127:0]  round_key_t,
    output wire [127:0]  round_key_f,
    output reg          key_valid
);
    reg [31:0] w_t[0:59];
    reg [31:0] w_f[0:59];
    reg [127:0] rk_t[0:14];
    reg [127:0] rk_f[0:14];

    reg [5:0] wi;
    reg [1:0] bi;
    reg [31:0] temp_t, temp_f;
    reg [1:0] state;
    localparam S_IDLE=2'd0, S_BYTES=2'd1, S_FINISH=2'd2;

    wire [31:0] prev_t = w_t[wi-1];
    wire [31:0] prev_f = w_f[wi-1];
    wire special = ((wi[2:0] == 3'd0) || (wi[2:0] == 3'd4));

    reg [7:0] sb_in_t, sb_in_f;
    wire [7:0] sb_out_t, sb_out_f;
    aes_sbox_byte u_sbox(.data_in_t(sb_in_t),.data_in_f(sb_in_f),.data_out_t(sb_out_t),.data_out_f(sb_out_f));

    function [7:0] rcon8;
        input [5:0] word_index;
        begin
            case(word_index)
                6'd8:  rcon8=8'h01; 6'd16: rcon8=8'h02; 6'd24:rcon8=8'h04;
                6'd32:rcon8=8'h08; 6'd40:rcon8=8'h10; 6'd48:rcon8=8'h20;
                6'd56:rcon8=8'h40; default:rcon8=8'h00;
            endcase
        end
    endfunction

    function [1:0] dx;
        input at,af,bt,bf;
        begin dx[1]=(at&bf)|(af&bt); dx[0]=(at&bt)|(af&bf); end
    endfunction

    integer j;
    reg [31:0] new_t,new_f;
    reg [31:0] rt,rf;
    reg [7:0] b_t,b_f;
    reg [1:0] z;
    reg [127:0] rkt_tmp,rkf_tmp;
    reg [7:0] rc_t, rc_f;

    always @(*) begin
        sb_in_t=8'h00; sb_in_f=8'hff;
        case(bi)
            2'd0: begin
                if(wi[2:0]==3'd0) begin sb_in_t=prev_t[23:16]; sb_in_f=prev_f[23:16]; end
                else sb_in_t=prev_t[31:24];
                if(wi[2:0]!=3'd0) sb_in_f=prev_f[31:24];
            end
            2'd1: begin sb_in_t=(wi[2:0]==3'd0)?prev_t[15:8]:prev_t[23:16]; sb_in_f=(wi[2:0]==3'd0)?prev_f[15:8]:prev_f[23:16]; end
            2'd2: begin sb_in_t=(wi[2:0]==3'd0)?prev_t[7:0]:prev_t[15:8]; sb_in_f=(wi[2:0]==3'd0)?prev_f[7:0]:prev_f[15:8]; end
            2'd3: begin sb_in_t=(wi[2:0]==3'd0)?prev_t[31:24]:prev_t[7:0]; sb_in_f=(wi[2:0]==3'd0)?prev_f[31:24]:prev_f[7:0]; end
        endcase
        if(!special) begin sb_in_t=8'h00; sb_in_f=8'hff; end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0; done<=0; key_valid<=0; state<=S_IDLE; wi<=0; bi<=0;
            temp_t<=0; temp_f<=0;
            for(j=0;j<60;j=j+1) begin w_t[j]<=0; w_f[j]<=0; end
            for(j=0;j<15;j=j+1) begin rk_t[j]<=0; rk_f[j]<=0; end
        end else begin
            done<=0; key_valid<=0;
            case(state)
            S_IDLE: begin
                if(start) begin
                    busy<=1; wi<=6'd8; bi<=0;
                    for(j=0;j<8;j=j+1) begin
                        w_t[j]<=key_in[255-j*32 -: 32];
                        w_f[j]<=~key_in[255-j*32 -: 32];
                    end
                    rk_t[0]<=key_in[255:128];
                    rk_f[0]<=~key_in[255:128];
                    rk_t[1]<=key_in[127:0];
                    rk_f[1]<=~key_in[127:0];
                    state<=special ? S_BYTES : S_FINISH;
                end
            end
            S_BYTES: begin
                b_t=sb_out_t; b_f=sb_out_f;
                if(wi[2:0]==3'd0 && bi==0) begin
                    // Bytewise dual-rail XOR against Rcon. dx() only takes
                    // scalar (1-bit) ports, so calling it with 8-bit vectors
                    // truncated everything down to bit 0 and lost the other
                    // 7 bits. AND/OR are already bitwise across a vector, so
                    // build the XOR directly instead of routing through dx().
                    rc_t = rcon8(wi);
                    rc_f = ~rcon8(wi);
                    b_t = (sb_out_t & rc_f) | (sb_out_f & rc_t);
                    b_f = (sb_out_t & rc_t) | (sb_out_f & rc_f);
                end
                case(bi)
                    2'd0: begin temp_t[31:24]<=b_t; temp_f[31:24]<=b_f; end
                    2'd1: begin temp_t[23:16]<=b_t; temp_f[23:16]<=b_f; end
                    2'd2: begin temp_t[15:8]<=b_t;  temp_f[15:8]<=b_f;  end
                    2'd3: begin temp_t[7:0]<=b_t;   temp_f[7:0]<=b_f;   end
                endcase
                if(bi==3) state<=S_FINISH; else bi<=bi+1'b1;
            end
            S_FINISH: begin
                // For non-S-box words, temp is simply RotWord/SubWord bypass data.
                // For ordinary words, the SubWord/RotWord block is bypassed.
                if(!special) begin
                    new_t = w_t[wi-8] ^ w_t[wi-1];
                    // Correct dual-rail XOR "false" output is (at&bt)|(af&bf),
                    // NOT a plain XOR of the two false rails: for single bits
                    // NOT(a)^NOT(b) == a^b, so XORing two genuinely-complementary
                    // false rails together just reproduces the true result
                    // instead of its complement.
                    new_f = (w_t[wi-8] & w_t[wi-1]) | (w_f[wi-8] & w_f[wi-1]);
                end else begin
                    new_t = w_t[wi-8] ^ temp_t;
                    new_f = (w_t[wi-8] & temp_t) | (w_f[wi-8] & temp_f);
                end
                w_t[wi]<=new_t; w_f[wi]<=new_f;
                if((wi % 4)==3) begin
                    rkt_tmp = {new_t,w_t[wi-1],w_t[wi-2],w_t[wi-3]};
                    rkf_tmp = {new_f,w_f[wi-1],w_f[wi-2],w_f[wi-3]};
                    rk_t[(wi/4)]<=rkt_tmp;
                    rk_f[(wi/4)]<=rkf_tmp;
                end
                if(wi==59) begin
                    busy<=0; done<=1; key_valid<=1; state<=S_IDLE;
                end else begin
                    wi<=wi+1'b1; bi<=0;
                    if(((wi+1'b1)%8)==0 || ((wi+1'b1)%8)==4) begin state<=S_BYTES; temp_t<=0; temp_f<=0; end
                    else begin state<=S_FINISH; temp_t<=w_t[wi]; temp_f<=w_f[wi]; end
                end
            end
            endcase
        end
    end

    assign   round_key_t = rk_t[round_sel];
    assign   round_key_f = rk_f[round_sel];
endmodule