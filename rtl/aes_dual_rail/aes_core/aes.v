module aes(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            decrypt,
    input   wire            encrypt,
    input   wire    [127:0] plaintext,
    input   wire            key_is_ready,
    input   wire    [255:0] key_in,

    output  wire    [127:0] data_out,
    output  wire            done
);

    // ----------------------------------------------------------------------
    // Shared functional units (ONE instance each for the whole chip)
    // ----------------------------------------------------------------------
    reg        sb_en, sb_de;
    reg  [7:0] sb_in_t, sb_in_f;
    wire [7:0] sb_out_t, sb_out_f;

    sub_byte_core u_sub_byte_core(
        .en(sb_en), .de(sb_de),
        .data_in_t(sb_in_t), .data_in_f(sb_in_f),
        .data_out_t(sb_out_t), .data_out_f(sb_out_f)
    );

    reg  [7:0] mc_a0_t,mc_a0_f,mc_a1_t,mc_a1_f,mc_a2_t,mc_a2_f,mc_a3_t,mc_a3_f;
    wire [7:0] mc_b0_t,mc_b0_f,mc_b1_t,mc_b1_f,mc_b2_t,mc_b2_f,mc_b3_t,mc_b3_f;

    mix_col_core u_mix_col_core(
        .a0_t(mc_a0_t),.a0_f(mc_a0_f),.a1_t(mc_a1_t),.a1_f(mc_a1_f),
        .a2_t(mc_a2_t),.a2_f(mc_a2_f),.a3_t(mc_a3_t),.a3_f(mc_a3_f),
        .b0_t(mc_b0_t),.b0_f(mc_b0_f),.b1_t(mc_b1_t),.b1_f(mc_b1_f),
        .b2_t(mc_b2_t),.b2_f(mc_b2_f),.b3_t(mc_b3_t),.b3_f(mc_b3_f)
    );

    reg  [7:0] imc_a0_t,imc_a0_f,imc_a1_t,imc_a1_f,imc_a2_t,imc_a2_f,imc_a3_t,imc_a3_f;
    wire [7:0] imc_b0_t,imc_b0_f,imc_b1_t,imc_b1_f,imc_b2_t,imc_b2_f,imc_b3_t,imc_b3_f;

    inv_mix_col_core u_inv_mix_col_core(
        .a0_t(imc_a0_t),.a0_f(imc_a0_f),.a1_t(imc_a1_t),.a1_f(imc_a1_f),
        .a2_t(imc_a2_t),.a2_f(imc_a2_f),.a3_t(imc_a3_t),.a3_f(imc_a3_f),
        .b0_t(imc_b0_t),.b0_f(imc_b0_f),.b1_t(imc_b1_t),.b1_f(imc_b1_f),
        .b2_t(imc_b2_t),.b2_f(imc_b2_f),.b3_t(imc_b3_t),.b3_f(imc_b3_f)
    );

    reg  [7:0] ark_key_t, ark_key_f, ark_data_t, ark_data_f;
    wire [7:0] ark_out_t, ark_out_f;

    add_round_key_core u_add_round_key_core(
        .key_t(ark_key_t), .key_f(ark_key_f),
        .data_t(ark_data_t), .data_f(ark_data_f),
        .data_out_t(ark_out_t), .data_out_f(ark_out_f)
    );

    // ----------------------------------------------------------------------
    // State / storage
    // ----------------------------------------------------------------------
    reg [7:0] state_t [0:15];
    reg [7:0] state_f [0:15];
    reg [7:0] pt_t    [0:15];   // latched input (plaintext or ciphertext), byte-sliced
    reg [7:0] pt_f    [0:15];
    reg [7:0] buf_a_t [0:15];   // post SubBytes/InvSubBytes (ShiftRows fused into addressing)
    reg [7:0] buf_a_f [0:15];
    reg [7:0] buf_b_t [0:15];   // post MixColumns (encrypt, non-final round only)
    reg [7:0] buf_b_f [0:15];
    reg [7:0] buf_c_t [0:15];   // post AddRoundKey, awaiting InvMixColumns (decrypt, non-final)
    reg [7:0] buf_c_f [0:15];

    reg [31:0] w_t [0:59];      // key schedule words (also serves as round-key storage)
    reg [31:0] w_f [0:59];

    reg [3:0] round;            // 0..14 during an op, 15 = idle/done sentinel (as original)
    reg       active, has_run, mode, encrypt_reg, decrypt_reg, key_ready_d;

    wire      key_start = key_is_ready & ~key_ready_d;
    wire      is_initial_round = (round == 4'd0);
    wire      is_final_round   = (round == 4'd14);
    wire [3:0] key_index = mode ? (4'd14 - round) : round;
    wire      do_mc  = (mode == 1'b0) && !is_final_round;  // MixColumns only: encrypt, non-final
    wire      do_imc = (mode == 1'b1) && !is_final_round;  // InvMixColumns only: decrypt, non-final

    // ----------------------------------------------------------------------
    // ShiftRows / InvShiftRows read-address tables (pure wiring, folded into
    // the SubBytes stage's source address -- costs 0 extra cycles/gates
    // beyond a small mux).
    // ----------------------------------------------------------------------
    function [3:0] sr_src;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:sr_src=4'd0;   4'd1:sr_src=4'd5;   4'd2:sr_src=4'd10;  4'd3:sr_src=4'd15;
                4'd4:sr_src=4'd4;   4'd5:sr_src=4'd9;   4'd6:sr_src=4'd14;  4'd7:sr_src=4'd3;
                4'd8:sr_src=4'd8;   4'd9:sr_src=4'd13;  4'd10:sr_src=4'd2; 4'd11:sr_src=4'd7;
                4'd12:sr_src=4'd12; 4'd13:sr_src=4'd1;  4'd14:sr_src=4'd6; 4'd15:sr_src=4'd11;
                default: sr_src = 4'd0;
            endcase
        end
    endfunction

    function [3:0] isr_src;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:isr_src=4'd0;  4'd1:isr_src=4'd13; 4'd2:isr_src=4'd10; 4'd3:isr_src=4'd7;
                4'd4:isr_src=4'd4;  4'd5:isr_src=4'd1;  4'd6:isr_src=4'd14; 4'd7:isr_src=4'd11;
                4'd8:isr_src=4'd8;  4'd9:isr_src=4'd5;  4'd10:isr_src=4'd2; 4'd11:isr_src=4'd15;
                4'd12:isr_src=4'd12;4'd13:isr_src=4'd9; 4'd14:isr_src=4'd6; 4'd15:isr_src=4'd3;
                default: isr_src = 4'd0;
            endcase
        end
    endfunction

    // Round-key key schedule byte access: round key `r` = words [4r .. 4r+3],
    // byte `b` (0..3) of a word is bits [31-8b -: 8] (MSB-first).
    function [7:0] rk_byte_t;
        input [3:0] r; input [3:0] idx;
        reg [6:0] widx; reg [1:0] b;
        begin
            widx = 4*r + idx[3:2];
            b    = idx[1:0];
            rk_byte_t = w_t[widx][31-8*b -: 8];
        end
    endfunction
    function [7:0] rk_byte_f;
        input [3:0] r; input [3:0] idx;
        reg [6:0] widx; reg [1:0] b;
        begin
            widx = 4*r + idx[3:2];
            b    = idx[1:0];
            rk_byte_f = w_f[widx][31-8*b -: 8];
        end
    endfunction

    function [7:0] rcon_byte;
        input [3:0] r;
        begin
            case (r)
                4'h1: rcon_byte = 8'h01;
                4'h2: rcon_byte = 8'h02;
                4'h3: rcon_byte = 8'h04;
                4'h4: rcon_byte = 8'h08;
                4'h5: rcon_byte = 8'h10;
                4'h6: rcon_byte = 8'h20;
                4'h7: rcon_byte = 8'h40;
                default: rcon_byte = 8'h00;
            endcase
        end
    endfunction

    // ----------------------------------------------------------------------
    // Master FSM
    // ----------------------------------------------------------------------
    localparam PH_IDLE       = 5'd0;
    localparam PH_KEXP_LOAD  = 5'd1;
    localparam PH_KEXP_PREP  = 5'd2;
    localparam PH_KEXP_SBOX  = 5'd3;
    localparam PH_KEXP_XOR   = 5'd4;
    localparam PH_KEXP_STEP  = 5'd5;
    localparam PH_RND_ENTRY  = 5'd6;
    localparam PH_SB         = 5'd7;
    localparam PH_MC         = 5'd8;
    localparam PH_ARK        = 5'd9;
    localparam PH_IMC        = 5'd10;
    localparam PH_ROUND_END  = 5'd11;

    reg [4:0] phase;
    reg [4:0] cnt;     // generic byte counter (0..15)
    reg [1:0] grp;     // column-group counter (0..3)
    reg [6:0] kexp_i;  // key-schedule word index (8..59)
    reg [1:0] kexp_j;  // byte-within-word counter (0..3)
    reg       kexp_case0, kexp_case4;
    reg [7:0] kexp_temp_t [0:3];
    reg [7:0] kexp_temp_f [0:3];

    integer ii;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round       <= 4'd15;
            active      <= 1'b0;
            has_run     <= 1'b0;
            mode        <= 1'b0;
            encrypt_reg <= 1'b0;
            decrypt_reg <= 1'b0;
            key_ready_d <= 1'b0;
            phase       <= PH_IDLE;
            cnt         <= 5'd0;
            grp         <= 2'd0;
            kexp_i      <= 7'd8;
            kexp_j      <= 2'd0;
            kexp_case0  <= 1'b0;
            kexp_case4  <= 1'b0;
            for (ii = 0; ii < 16; ii = ii + 1) begin
                state_t[ii] <= 8'b0; state_f[ii] <= 8'b0;
                pt_t[ii]    <= 8'b0; pt_f[ii]    <= 8'b0;
            end
        end else begin
            key_ready_d <= key_is_ready;

            if (encrypt) encrypt_reg <= 1'b1;
            else if (decrypt) decrypt_reg <= 1'b1;
            else if (done) begin
                encrypt_reg <= 1'b0;
                decrypt_reg <= 1'b0;
            end

            case (phase)
            // ---------------------------------------------------------
            PH_IDLE: begin
                if (!active && key_start && (encrypt || decrypt)) begin
                    active  <= 1'b1;
                    has_run <= 1'b1;
                    mode    <= decrypt;
                    for (ii = 0; ii < 16; ii = ii + 1) begin
                        pt_t[ii] <= plaintext[127-8*ii -: 8];
                        pt_f[ii] <= ~plaintext[127-8*ii -: 8];
                    end
                    phase  <= PH_KEXP_LOAD;
                end
            end

            // ---------------- Key expansion (runs once per key_start) ---
            PH_KEXP_LOAD: begin
                for (ii = 0; ii < 8; ii = ii + 1) begin
                    w_t[ii] <= key_in[255-ii*32 -: 32];
                    w_f[ii] <= ~key_in[255-ii*32 -: 32];
                end
                kexp_i <= 7'd8;
                phase  <= PH_KEXP_PREP;
            end

            PH_KEXP_PREP: begin
                kexp_case0 <= (kexp_i[2:0] == 3'd0);
                kexp_case4 <= (kexp_i[2:0] == 3'd4);
                kexp_j     <= 2'd0;
                if ((kexp_i[2:0] == 3'd0) || (kexp_i[2:0] == 3'd4))
                    phase <= PH_KEXP_SBOX;
                else
                    phase <= PH_KEXP_XOR;
            end

            PH_KEXP_SBOX: begin
                // in_byte = case0 ? RotWord(w[i-1])[j] : w[i-1][j]
                // RotWord byte j = w[i-1] byte (j+1)%4
                kexp_temp_t[kexp_j] <= (kexp_case0 && kexp_j == 2'd0)
                                       ? (sb_out_t ^ rcon_byte(kexp_i[6:3])) : sb_out_t;
                kexp_temp_f[kexp_j] <= (kexp_case0 && kexp_j == 2'd0)
                                       ? (sb_out_f ^ rcon_byte(kexp_i[6:3])) : sb_out_f;
                if (kexp_j == 2'd3) begin
                    kexp_j <= 2'd0;
                    phase  <= PH_KEXP_XOR;
                end else
                    kexp_j <= kexp_j + 1'b1;
            end

            PH_KEXP_XOR: begin
                w_t[kexp_i][31-8*kexp_j -: 8] <= ark_out_t;
                w_f[kexp_i][31-8*kexp_j -: 8] <= ark_out_f;
                if (kexp_j == 2'd3) begin
                    phase <= PH_KEXP_STEP;
                end else
                    kexp_j <= kexp_j + 1'b1;
            end

            PH_KEXP_STEP: begin
                if (kexp_i == 7'd59) begin
                    round <= 4'd0;
                    phase <= PH_RND_ENTRY;
                end else begin
                    kexp_i <= kexp_i + 1'b1;
                    phase  <= PH_KEXP_PREP;
                end
            end

            // ---------------------------- Round datapath -----------------
            PH_RND_ENTRY: begin
                cnt <= 5'd0;
                if (is_initial_round)
                    phase <= PH_ARK;
                else
                    phase <= PH_SB;
            end

            PH_SB: begin
                buf_a_t[cnt] <= sb_out_t;
                buf_a_f[cnt] <= sb_out_f;
                if (cnt == 5'd15) begin
                    cnt <= 5'd0;
                    grp <= 2'd0;
                    phase <= do_mc ? PH_MC : PH_ARK;
                end else
                    cnt <= cnt + 1'b1;
            end

            PH_MC: begin
                buf_b_t[{grp,2'd0}] <= mc_b0_t; buf_b_f[{grp,2'd0}] <= mc_b0_f;
                buf_b_t[{grp,2'd1}] <= mc_b1_t; buf_b_f[{grp,2'd1}] <= mc_b1_f;
                buf_b_t[{grp,2'd2}] <= mc_b2_t; buf_b_f[{grp,2'd2}] <= mc_b2_f;
                buf_b_t[{grp,2'd3}] <= mc_b3_t; buf_b_f[{grp,2'd3}] <= mc_b3_f;
                if (grp == 2'd3) begin
                    cnt <= 5'd0;
                    phase <= PH_ARK;
                end else
                    grp <= grp + 1'b1;
            end

            PH_ARK: begin
                if ((mode == 1'b0) || is_final_round || is_initial_round) begin
                    state_t[cnt] <= ark_out_t;
                    state_f[cnt] <= ark_out_f;
                end else begin
                    buf_c_t[cnt] <= ark_out_t;
                    buf_c_f[cnt] <= ark_out_f;
                end
                if (cnt == 5'd15) begin
                    if ((mode == 1'b0) || is_final_round || is_initial_round) begin
                        phase <= PH_ROUND_END;
                    end else begin
                        grp   <= 2'd0;
                        phase <= PH_IMC;
                    end
                end else
                    cnt <= cnt + 1'b1;
            end

            PH_IMC: begin
                state_t[{grp,2'd0}] <= imc_b0_t; state_f[{grp,2'd0}] <= imc_b0_f;
                state_t[{grp,2'd1}] <= imc_b1_t; state_f[{grp,2'd1}] <= imc_b1_f;
                state_t[{grp,2'd2}] <= imc_b2_t; state_f[{grp,2'd2}] <= imc_b2_f;
                state_t[{grp,2'd3}] <= imc_b3_t; state_f[{grp,2'd3}] <= imc_b3_f;
                if (grp == 2'd3)
                    phase <= PH_ROUND_END;
                else
                    grp <= grp + 1'b1;
            end

            PH_ROUND_END: begin
                if (round == 4'd14) begin
                    round  <= 4'd15;
                    active <= 1'b0;
                    phase  <= PH_IDLE;
                end else begin
                    round <= round + 1'b1;
                    phase <= PH_RND_ENTRY;
                end
            end

            default: phase <= PH_IDLE;
            endcase
        end
    end

    // ----------------------------------------------------------------------
    // Combinational source muxing into the shared cores
    // ----------------------------------------------------------------------
    always @(*) begin
        // Defaults
        sb_en = 1'b1; sb_de = 1'b0;
        sb_in_t = 8'b0; sb_in_f = 8'b0;
        ark_key_t = 8'b0; ark_key_f = 8'b0;
        ark_data_t = 8'b0; ark_data_f = 8'b0;
        mc_a0_t=8'b0;mc_a0_f=8'b0;mc_a1_t=8'b0;mc_a1_f=8'b0;
        mc_a2_t=8'b0;mc_a2_f=8'b0;mc_a3_t=8'b0;mc_a3_f=8'b0;
        imc_a0_t=8'b0;imc_a0_f=8'b0;imc_a1_t=8'b0;imc_a1_f=8'b0;
        imc_a2_t=8'b0;imc_a2_f=8'b0;imc_a3_t=8'b0;imc_a3_f=8'b0;

        case (phase)
            PH_KEXP_SBOX: begin
                sb_en = 1'b1; sb_de = 1'b0;
                if (kexp_case0) begin
                    sb_in_t = w_t[kexp_i-1][31-8*((kexp_j+1)&2'd3) -: 8];
                    sb_in_f = w_f[kexp_i-1][31-8*((kexp_j+1)&2'd3) -: 8];
                end else begin
                    sb_in_t = w_t[kexp_i-1][31-8*kexp_j -: 8];
                    sb_in_f = w_f[kexp_i-1][31-8*kexp_j -: 8];
                end
            end

            PH_KEXP_XOR: begin
                ark_key_t = (kexp_case0 || kexp_case4) ? kexp_temp_t[kexp_j] : w_t[kexp_i-1][31-8*kexp_j -: 8];
                ark_key_f = (kexp_case0 || kexp_case4) ? kexp_temp_f[kexp_j] : w_f[kexp_i-1][31-8*kexp_j -: 8];
                ark_data_t = w_t[kexp_i-8][31-8*kexp_j -: 8];
                ark_data_f = w_f[kexp_i-8][31-8*kexp_j -: 8];
            end

            PH_SB: begin
                sb_en = ~mode;
                sb_de = mode;
                sb_in_t = mode ? state_t[isr_src(cnt[3:0])] : state_t[sr_src(cnt[3:0])];
                sb_in_f = mode ? state_f[isr_src(cnt[3:0])] : state_f[sr_src(cnt[3:0])];
            end

            PH_MC: begin
                mc_a0_t = buf_a_t[{grp,2'd0}]; mc_a0_f = buf_a_f[{grp,2'd0}];
                mc_a1_t = buf_a_t[{grp,2'd1}]; mc_a1_f = buf_a_f[{grp,2'd1}];
                mc_a2_t = buf_a_t[{grp,2'd2}]; mc_a2_f = buf_a_f[{grp,2'd2}];
                mc_a3_t = buf_a_t[{grp,2'd3}]; mc_a3_f = buf_a_f[{grp,2'd3}];
            end

            PH_ARK: begin
                ark_key_t = rk_byte_t(key_index, cnt[3:0]);
                ark_key_f = rk_byte_f(key_index, cnt[3:0]);
                if (is_initial_round) begin
                    ark_data_t = pt_t[cnt[3:0]];
                    ark_data_f = pt_f[cnt[3:0]];
                end else if (do_mc) begin
                    ark_data_t = buf_b_t[cnt[3:0]];
                    ark_data_f = buf_b_f[cnt[3:0]];
                end else begin
                    ark_data_t = buf_a_t[cnt[3:0]];
                    ark_data_f = buf_a_f[cnt[3:0]];
                end
            end

            PH_IMC: begin
                imc_a0_t = buf_c_t[{grp,2'd0}]; imc_a0_f = buf_c_f[{grp,2'd0}];
                imc_a1_t = buf_c_t[{grp,2'd1}]; imc_a1_f = buf_c_f[{grp,2'd1}];
                imc_a2_t = buf_c_t[{grp,2'd2}]; imc_a2_f = buf_c_f[{grp,2'd2}];
                imc_a3_t = buf_c_t[{grp,2'd3}]; imc_a3_f = buf_c_f[{grp,2'd3}];
            end

            default: ; // idle - inputs stay at default 0
        endcase
    end

    assign done = (round == 4'd15) && !active && has_run;
    assign data_out = { state_t[0], state_t[1], state_t[2],  state_t[3],
                         state_t[4], state_t[5], state_t[6],  state_t[7],
                         state_t[8], state_t[9], state_t[10], state_t[11],
                         state_t[12],state_t[13],state_t[14], state_t[15] };

endmodule
