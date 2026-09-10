module aes(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            decrypt,
    input   wire            encrypt,
    //Input value from RISC-V: plaintext khi encrypt, ciphertext khi decrypt
    input   wire    [127:0] plaintext,
    //Input value from SHA
    input   wire            key_is_ready,
    input   wire    [255:0] key_in,

    output  wire    [127:0] data_out,
    output  wire            done
);
    wire    [1919:0]     ke_out_t, ke_out_f;
    reg     [127:0]      key_t, key_f;
    wire    [127:0]      enc_ark_out_t, enc_ark_out_f;
    wire    [127:0]      dec_ark_out_t, dec_ark_out_f;
    wire    [127:0]      ark_out_t, ark_out_f;
    reg     [127:0]      state_t, state_f;
    reg     [3:0]        round;
    wire    [127:0]      state_in_t, state_in_f;
    wire                 is_initial_round, is_final_round;

    reg     [127:0]      prev_plaintext;
    reg                  has_run;
    reg                  active;
    reg                  mode;     
    reg                  encrypt_reg, decrypt_reg;    
    wire                 key_start;
    reg                  key_ready_d;

    wire    [3:0]         key_index;

    assign  key_index = mode ? (4'd14 - round) : round;

    assign state_in_t = (round == 4'd0) ? plaintext  : state_t;
    assign state_in_f = (round == 4'd0) ? ~plaintext : state_f;

    assign is_initial_round = (round == 4'd0);
    assign is_final_round   = (round == 4'd14);

    assign key_start = key_is_ready & ~key_ready_d;

    key_expansion key_expansion_0(
        .key_in(key_in),
        .w_out_t(ke_out_t),
        .w_out_f(ke_out_f)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            key_ready_d <= 0;
        else
            key_ready_d <= key_is_ready;
    end
    

    always @(*) begin
        case (key_index)
            4'd0 : key_t = ke_out_t[1919:1792];
            4'd1 : key_t = ke_out_t[1791:1664];
            4'd2 : key_t = ke_out_t[1663:1536];
            4'd3 : key_t = ke_out_t[1535:1408];
            4'd4 : key_t = ke_out_t[1407:1280];
            4'd5 : key_t = ke_out_t[1279:1152];
            4'd6 : key_t = ke_out_t[1151:1024];
            4'd7 : key_t = ke_out_t[1023:896];
            4'd8 : key_t = ke_out_t[895:768];
            4'd9 : key_t = ke_out_t[767:640];
            4'd10: key_t = ke_out_t[639:512];
            4'd11: key_t = ke_out_t[511:384];
            4'd12: key_t = ke_out_t[383:256];
            4'd13: key_t = ke_out_t[255:128];
            4'd14: key_t = ke_out_t[127:0];
            default: key_t = 128'b0;
        endcase
    end

    always @(*) begin
        case (key_index)
            4'd0 : key_f = ke_out_f[1919:1792];
            4'd1 : key_f = ke_out_f[1791:1664];
            4'd2 : key_f = ke_out_f[1663:1536];
            4'd3 : key_f = ke_out_f[1535:1408];
            4'd4 : key_f = ke_out_f[1407:1280];
            4'd5 : key_f = ke_out_f[1279:1152];
            4'd6 : key_f = ke_out_f[1151:1024];
            4'd7 : key_f = ke_out_f[1023:896];
            4'd8 : key_f = ke_out_f[895:768];
            4'd9 : key_f = ke_out_f[767:640];
            4'd10: key_f = ke_out_f[639:512];
            4'd11: key_f = ke_out_f[511:384];
            4'd12: key_f = ke_out_f[383:256];
            4'd13: key_f = ke_out_f[255:128];
            4'd14: key_f = ke_out_f[127:0];
            default: key_f = 128'b0;
        endcase
    end

    aes_encrypt encrypt_inst(
        .is_initial_round(is_initial_round),
        .is_final_round(is_final_round),
        .data_t(state_in_t),
        .data_f(state_in_f),
        .key_t(key_t),
        .key_f(key_f),
        .data_out_t(enc_ark_out_t),
        .data_out_f(enc_ark_out_f)
    );

    aes_decrypt decrypt_inst(
        .is_initial_round(is_initial_round),
        .is_final_round(is_final_round),
        .data_t(state_in_t),
        .data_f(state_in_f),
        .key_t(key_t),
        .key_f(key_f),
        .data_out_t(dec_ark_out_t),
        .data_out_f(dec_ark_out_f)
    );

    assign ark_out_t = mode ? dec_ark_out_t : enc_ark_out_t;
    assign ark_out_f = mode ? dec_ark_out_f : enc_ark_out_f;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            round          <= 4'd15;
            state_t        <= 128'b0;
            state_f        <= 128'b0;
            prev_plaintext <= 128'b0;
            has_run        <= 1'b0;
            active         <= 1'b0;
            mode           <= 1'b0;
            encrypt_reg    <= 1'b0;
            decrypt_reg    <= 1'b0;
        end
        else begin

            if(encrypt) begin
                encrypt_reg    <= 1'b1;
            end
            else if(decrypt) begin
                decrypt_reg    <= 1'b1;
            end
            else if(done) begin
                encrypt_reg    <= 1'b0;
                decrypt_reg    <= 1'b0;
            end

            if (!active && key_start && (encrypt || decrypt)) begin
                round          <= 4'd0;
                active         <= 1'b1;
                has_run        <= 1'b1;
                mode           <= decrypt;      
                prev_plaintext <= plaintext;
            end

            else if (active) begin
                if (round < 4'd14) begin
                    round   <= round + 1'b1;
                    state_t <= ark_out_t;
                    state_f <= ark_out_f;
                end
                else if (round == 4'd14) begin
                    round   <= round + 1'b1;
                    state_t <= ark_out_t;
                    state_f <= ark_out_f;
                    active  <= 1'b0;
                end
            end
        end
    end


    assign done     = (round == 4'd15) && !active && has_run;
    assign data_out = state_t;

endmodule
