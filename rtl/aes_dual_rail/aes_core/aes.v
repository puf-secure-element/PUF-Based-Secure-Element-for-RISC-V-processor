// AES-256 dual-rail BYTE-SERIAL controller.
//
// Datapath policy:
//   * one AES S-box (one GF + affine pair) is reused for one byte/cycle
//   * SubBytes/InvSubBytes = 16 cycles/round
//   * MixColumns/InvMixColumns = 4 cycles/round internally, followed by
//     serial AddRoundKey = 16 cycles/round
//   * AES-256 key expansion is sequential and reuses the same single-byte S-box
//
// Interface is kept compatible with the original top-level AES module.
module aes (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            decrypt,
    input   wire            encrypt,
    input   wire [127:0]    plaintext,
    input   wire            key_is_ready,
    input   wire [255:0]    key_in,
    output  wire [127:0]    data_out,
    output  wire            done
);
    localparam ST_IDLE=4'd0,
               ST_KEYWAIT=4'd1,
               ST_SUB=4'd2,
               ST_MIX=4'd3,
               ST_ARK=4'd4,
               ST_FINISH=4'd5;

    reg [3:0] st;
    reg [3:0] round;
    reg [3:0] byte_idx;
    reg [1:0] col_idx;
    reg       mode;
    reg       enc_latched, dec_latched;
    reg       key_ready_d;
    reg       run_pending;
    reg       done_r;

    reg [127:0] state_t, state_f;
    reg [127:0] sb_state_t, sb_state_f;
    reg [127:0] mix_state_t, mix_state_f;

    wire key_start = key_is_ready & ~key_ready_d;

    reg [3:0] key_round_sel;
    wire [127:0] round_key_t, round_key_f;
    wire key_busy, key_done, key_valid;

    aes_key_expansion_serial u_keyexp (
        .clk(clk), .rst_n(rst_n),
        .start(key_start && (encrypt || decrypt || enc_latched || dec_latched)),
        .key_in(key_in),
        .round_sel(key_round_sel),
        .busy(key_busy), .done(key_done), .key_valid(key_valid),
        .round_key_t(round_key_t), .round_key_f(round_key_f)
    );

    // One shared GF/S-box datapath. The affine direction is selected by mode.
    // After the first decryption round, InvMixColumns leaves the next state in
    // mix_state; encryption keeps its round state in state_t.
    wire [127:0] sb_src_t = (mode && (round>1)) ? mix_state_t : state_t;
    wire [127:0] sb_src_f = (mode && (round>1)) ? mix_state_f : state_f;
    wire [7:0] cur_in_t = sb_src_t[127-byte_idx*8 -: 8];
    wire [7:0] cur_in_f = sb_src_f[127-byte_idx*8 -: 8];
    wire [7:0] inv_aff_t, inv_aff_f;
    wire [7:0] gf_in_t = mode ? inv_aff_t : cur_in_t;
    wire [7:0] gf_in_f = mode ? inv_aff_f : cur_in_f;
    wire [7:0] gf_out_t, gf_out_f;
    wire [7:0] aff_out_t, aff_out_f;

    inv_aff u_inv_aff (
        .inv_aff_in_t(cur_in_t), .inv_aff_in_f(cur_in_f),
        .inv_aff_out_t(inv_aff_t), .inv_aff_out_f(inv_aff_f)
    );
    GF u_shared_gf (
        .data_in_t(gf_in_t), .data_in_f(gf_in_f),
        .data_out_t(gf_out_t), .data_out_f(gf_out_f)
    );
    aff_trans u_aff (
        .aff_trans_in_t(gf_out_t), .aff_trans_in_f(gf_out_f),
        .aff_trans_out_t(aff_out_t), .aff_trans_out_f(aff_out_f)
    );

    // In decrypt mode the inverse affine precedes GF; in encrypt mode GF
    // is followed by the normal affine transform.
    wire [7:0] cur_sbox_t = aff_out_t;
    wire [7:0] cur_sbox_f = aff_out_f;
    wire [7:0] cur_isb_t  = gf_out_t;
    wire [7:0] cur_isb_f  = gf_out_f;

    // ShiftRows mapping is performed by the byte write address, so no
    // dedicated 128-bit ShiftRows network is required.
    reg [3:0] sb_dst_idx;
    always @(*) begin
        if(!mode)
            sb_dst_idx = (((byte_idx/4) - (byte_idx%4) + 4) % 4)*4 + (byte_idx%4);
        else
            sb_dst_idx = (((byte_idx/4) + (byte_idx%4)) % 4)*4 + (byte_idx%4);
    end

    // One column per cycle MixColumns engine.
    wire [127:0] mix_src_t = mode ? state_t : sb_state_t;
    wire [127:0] mix_src_f = mode ? state_f : sb_state_f;
    wire [31:0] mix_in_t = mix_src_t[127-col_idx*32 -: 32];
    wire [31:0] mix_in_f = mix_src_f[127-col_idx*32 -: 32];
    wire [31:0] mix_out_t, mix_out_f;
    aes_mix_column_serial u_mix (
        .decrypt(mode),
        .in_t(mix_in_t), .in_f(mix_in_f),
        .out_t(mix_out_t), .out_f(mix_out_f)
    );

    // Byte-wise dual-rail XOR for AddRoundKey.
    wire [127:0] ark_src_t = (round==0) ? {128{1'b0}} :
                              (mode ? sb_state_t : ((round==14) ? sb_state_t : mix_state_t));
    wire [127:0] ark_src_f = (round==0) ? {128{1'b1}} :
                              (mode ? sb_state_f : ((round==14) ? sb_state_f : mix_state_f));
    wire [7:0] ark_data_t = (round==0) ? plaintext[127-byte_idx*8 -:8] : ark_src_t[127-byte_idx*8 -:8];
    wire [7:0] ark_data_f = (round==0) ? ~plaintext[127-byte_idx*8 -:8] : ark_src_f[127-byte_idx*8 -:8];
    wire [7:0] ark_key_t = round_key_t[127-byte_idx*8 -:8];
    wire [7:0] ark_key_f = round_key_f[127-byte_idx*8 -:8];
    wire [7:0] ark_byte_t = (ark_data_t & ark_key_f) | (ark_data_f & ark_key_t);
    wire [7:0] ark_byte_f = (ark_data_t & ark_key_t) | (ark_data_f & ark_key_f);

    // Key used by AES decryption is selected in reverse order.
    always @(*) begin
        if(!mode) key_round_sel = round;
        else if(round <= 4'd14) key_round_sel = 4'd14 - round;
        else key_round_sel = 4'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=ST_IDLE; round<=0; byte_idx<=0; col_idx<=0; mode<=0;
            enc_latched<=0; dec_latched<=0; key_ready_d<=0; run_pending<=0;
            done_r<=0; state_t<=0; state_f<=0; sb_state_t<=0; sb_state_f<=0;
            mix_state_t<=0; mix_state_f<=0;
        end else begin
            key_ready_d <= key_is_ready;
            done_r <= 1'b0;

            if(encrypt) begin enc_latched<=1'b1; dec_latched<=1'b0; end
            if(decrypt) begin dec_latched<=1'b1; enc_latched<=1'b0; end

            case(st)
            ST_IDLE: begin
                if(key_start && (enc_latched || dec_latched)) begin
                    mode <= decrypt ? 1'b1 : dec_latched;
                    run_pending <= 1'b1;
                    st <= ST_KEYWAIT;
                end
            end

            ST_KEYWAIT: begin
                if(key_done) begin
                    round <= 0;
                    byte_idx <= 0;
                    // Initial AddRoundKey is serialized using round key 0 for
                    // encryption and round key 14 for decryption.
                    st <= ST_ARK;
                end
            end

            ST_ARK: begin
                if(round==0) begin
                    // Initial key: encrypt key 0, decrypt key 14.
                    state_t[127-byte_idx*8 -:8] <=
                        ((mode ? plaintext[127-byte_idx*8 -:8] : plaintext[127-byte_idx*8 -:8]) &
                         round_key_f[127-byte_idx*8 -:8]) |
                        (~plaintext[127-byte_idx*8 -:8] & round_key_t[127-byte_idx*8 -:8]);
                    state_f[127-byte_idx*8 -:8] <=
                        ((mode ? plaintext[127-byte_idx*8 -:8] : plaintext[127-byte_idx*8 -:8]) &
                         round_key_t[127-byte_idx*8 -:8]) |
                        (~plaintext[127-byte_idx*8 -:8] & round_key_f[127-byte_idx*8 -:8]);
                    if(byte_idx==15) begin
                        round <= 1;
                        byte_idx <= 0;
                        st <= ST_SUB;
                    end else byte_idx <= byte_idx+1'b1;
                end else begin
                    state_t[127-byte_idx*8 -:8] <= ark_byte_t;
                    state_f[127-byte_idx*8 -:8] <= ark_byte_f;
                    if(byte_idx==15) begin
                        if(round==14) st<=ST_FINISH;
                        else begin round<=round+1'b1; byte_idx<=0; st<=ST_SUB; end
                    end else byte_idx<=byte_idx+1'b1;
                end
            end

            ST_SUB: begin
                // One S-box operation per clock. ShiftRows is encoded in sb_dst_idx.
                sb_state_t[127-sb_dst_idx*8 -:8] <= mode ? cur_isb_t : cur_sbox_t;
                sb_state_f[127-sb_dst_idx*8 -:8] <= mode ? cur_isb_f : cur_sbox_f;
                if(byte_idx==15) begin
                    byte_idx<=0;
                    col_idx<=0;
                    if(round==14) begin
                        // Final round: no MixColumns.
                        st<=ST_ARK;
                    end else begin
                        st<=ST_MIX;
                    end
                end else byte_idx<=byte_idx+1'b1;
            end

            ST_MIX: begin
                mix_state_t[127-col_idx*32 -:32] <= mix_out_t;
                mix_state_f[127-col_idx*32 -:32] <= mix_out_f;
                if(col_idx==3) begin
                    col_idx<=0; byte_idx<=0;
                    if(mode) begin
                        round<=round+1'b1;
                        st<=ST_SUB;
                    end else begin
                        st<=ST_ARK;
                    end
                end else col_idx<=col_idx+1'b1;
            end

            ST_FINISH: begin
                done_r<=1'b1;
                st<=ST_IDLE;
                enc_latched<=0; dec_latched<=0; run_pending<=0;
            end
            endcase
        end
    end

    assign data_out = state_t;
    assign done = done_r;

initial begin

    forever begin
        @(posedge dut.clk);

        // ==========================================================
        // AES DEBUG MONITOR
        // ==========================================================

        if (state_t != 0) begin

            $display("");
            $display("==============================================================");
            $display("[AES MONITOR] TIME = %0t", $time);
            $display("--------------------------------------------------------------");

            $display("[CTRL]");
            $display("  round       = %0d", round);

            $display("");
            $display("[STATE]");
            $display("  STATE_T     = %032h", state_t);
            $display("  STATE_F     = %032h", state_f);
            $display("  XOR         = %032h",
                     state_t ^ state_f);

            $display("");
            $display("[KEY]");
            $display("  KEY_T       = %032h", round_key_t);
            $display("  KEY_F       = %032h", round_key_f);
            $display("  KEY_XOR     = %032h",
                     round_key_t ^ round_key_f);

            $display("");
            $display("[CHECK]");
            if ((state_t ^ state_f)
                 == 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                $display("  STATE DUAL-RAIL = VALID");
            else
                $display("  STATE DUAL-RAIL = INVALID");

            if ((round_key_t ^ round_key_f)
                 == 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                $display("  KEY   DUAL-RAIL = VALID");
            else
                $display("  KEY   DUAL-RAIL = INVALID");

            $display("==============================================================");
        end
    end

end

endmodule
