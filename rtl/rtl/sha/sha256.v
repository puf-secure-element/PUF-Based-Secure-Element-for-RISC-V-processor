module sha256 (
    input  wire         clk,
    input  wire         rst_n,
    //Each block is 512 bits
    input  wire         start,      //For block 0, if data <= 512 bits
    input  wire         next,       //For block 1, if data > 512 bits
    input  wire [511:0] data_in,

    output wire [255:0] hash_out,
    output wire         hash_valid, //Hash is valid 
    output wire         done        //Core is available for next block
);
    //SHA FSM states
    parameter IDLE = 2'b00, ROUNDS = 2'b01, DONE = 2'b10;
    parameter SHA_ROUNDS = 6'd63;
    //Initial hash values (H0) for SHA-256
    parameter SHA_H0_0 = 32'h6a09e667;
    parameter SHA_H0_1 = 32'hbb67ae85;
    parameter SHA_H0_2 = 32'h3c6ef372;
    parameter SHA_H0_3 = 32'ha54ff53a;
    parameter SHA_H0_4 = 32'h510e527f;
    parameter SHA_H0_5 = 32'h9b05688c;
    parameter SHA_H0_6 = 32'h1f83d9ab;
    parameter SHA_H0_7 = 32'h5be0cd19;

    reg     [1:0]   state, state_reg;
    wire    [31:0]  w;
    wire    [31:0]  k;
    reg     [31:0]  sum1, sum0, ch, maj;
    reg             hash_valid_reg, first_block;
    reg             ready_flag;
    reg     [31:0]  t1, t2;
    reg             hash_valid_we, hash_valid_new;
    reg             hash_valid_rst;

    //
    reg             a2h_we;
    reg     [31:0]  a_reg;
    reg     [31:0]  a_new;
    reg     [31:0]  b_reg;
    reg     [31:0]  b_new;
    reg     [31:0]  c_reg;
    reg     [31:0]  c_new;
    reg     [31:0]  d_reg;
    reg     [31:0]  d_new;
    reg     [31:0]  e_reg;
    reg     [31:0]  e_new;
    reg     [31:0]  f_reg;
    reg     [31:0]  f_new;
    reg     [31:0]  g_reg;
    reg     [31:0]  g_new;
    reg     [31:0]  h_reg;
    reg     [31:0]  h_new;

    //Hash values
    reg             h_we;
    reg     [31:0]  h0_reg;
    reg     [31:0]  h0_new;
    reg     [31:0]  h1_reg;
    reg     [31:0]  h1_new;
    reg     [31:0]  h2_reg;
    reg     [31:0]  h2_new;
    reg     [31:0]  h3_reg;
    reg     [31:0]  h3_new;
    reg     [31:0]  h4_reg;
    reg     [31:0]  h4_new;
    reg     [31:0]  h5_reg;
    reg     [31:0]  h5_new;
    reg     [31:0]  h6_reg;
    reg     [31:0]  h6_new;
    reg     [31:0]  h7_reg;
    reg     [31:0]  h7_new;

    //ROUNDS signals
    reg     [5:0]   round_cnt_new, round_cnt_reg;
    reg             round_cnt_we, round_rst, round_inc;

    //Control signals
    reg             state_update;

    assign hash_valid   = hash_valid_reg;
    assign hash_out     = {h0_reg, h1_reg, h2_reg, h3_reg, h4_reg, h5_reg, h6_reg, h7_reg};
    assign done         = ready_flag;

    sha256_m_schedule m_schedule (
        .clk(clk),
        .rst_n(rst_n),
        .block(data_in),
        .start(start),
        .next(next),
        .round(round_cnt_reg),
        .w_out(w)
    );

    sha256_k_constant k_constant (
        .round(round_cnt_reg),
        .k_out(k)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            a_reg          <= 32'h0;
            b_reg          <= 32'h0;
            c_reg          <= 32'h0;
            d_reg          <= 32'h0;
            e_reg          <= 32'h0;
            f_reg          <= 32'h0;
            g_reg          <= 32'h0;
            h_reg          <= 32'h0;

            h0_reg          <= 32'h0;
            h1_reg          <= 32'h0;
            h2_reg          <= 32'h0;
            h3_reg          <= 32'h0;
            h4_reg          <= 32'h0;
            h5_reg          <= 32'h0;
            h6_reg          <= 32'h0;
            h7_reg          <= 32'h0;

            round_cnt_reg   <= 6'd0;
            state_reg       <= IDLE;

            hash_valid_reg  <= 1'b0;
        end 
        else begin
            //Hash computation logic here
            //Update hash_out, hash_valid, and done signals based on the SHA-256 algorithm
            if(state_update) begin
                state_reg       <= state;
            end

            if(round_cnt_we) begin
                round_cnt_reg   <= round_cnt_new;
            end

            if(a2h_we) begin
                a_reg   <= a_new;
                b_reg   <= b_new;
                c_reg   <= c_new;
                d_reg   <= d_new;
                e_reg   <= e_new;
                f_reg   <= f_new;
                g_reg   <= g_new;
                h_reg   <= h_new;
            end

            if(h_we) begin
                h0_reg  <= h0_new;
                h1_reg  <= h1_new;
                h2_reg  <= h2_new;
                h3_reg  <= h3_new;
                h4_reg  <= h4_new;
                h5_reg  <= h5_new;
                h6_reg  <= h6_new;
                h7_reg  <= h7_new;
            end

            if(hash_valid_we) begin
                hash_valid_reg   <= hash_valid_new;
            end
        end
    end

    //T1 Calculation
    //SHA formula: T1 = h + Σ1​(e) + Ch(e,f,g) + Kt ​+ Wt​
    always @(*) begin
        sum1 = {e_reg[5:0], e_reg[31:6]} ^
            {e_reg[10:0], e_reg[31:11]} ^
            {e_reg[24:0], e_reg[31:25]};

        ch = (e_reg & f_reg) ^ ((~e_reg) & g_reg);
        
        t1 = h_reg + sum1 + ch + w + k;
    end

    //T2 Calculation
    //SHA formula: T2 = Σ0​(a) + Maj(a,b,c)
    always @(*) begin
        sum0 = {a_reg[1:0], a_reg[31:2]} ^
            {a_reg[12:0], a_reg[31:13]} ^
            {a_reg[21:0], a_reg[31:22]};

        maj = (a_reg & b_reg) ^ (a_reg & c_reg) ^ (b_reg & c_reg);

        t2 = sum0 + maj;
    end

    always @(*) begin
        h0_new  = 32'h0;
        h1_new  = 32'h0;
        h2_new  = 32'h0;
        h3_new  = 32'h0;
        h4_new  = 32'h0;
        h5_new  = 32'h0;
        h6_new  = 32'h0;
        h7_new  = 32'h0;
        h_we    = 1'b0;
        if(state_reg == IDLE && start) begin
            h_we = 1'b1;
            h0_new = SHA_H0_0;
            h1_new = SHA_H0_1;
            h2_new = SHA_H0_2;
            h3_new = SHA_H0_3;
            h4_new = SHA_H0_4;
            h5_new = SHA_H0_5;
            h6_new = SHA_H0_6;
            h7_new = SHA_H0_7;
        end
        else if(state_reg == DONE) begin
            h0_new = h0_reg + a_reg;
            h1_new = h1_reg + b_reg;
            h2_new = h2_reg + c_reg;
            h3_new = h3_reg + d_reg;
            h4_new = h4_reg + e_reg;
            h5_new = h5_reg + f_reg;
            h6_new = h6_reg + g_reg;
            h7_new = h7_reg + h_reg;
            h_we = 1'b1;
        end
    end

    always @(*) begin
        a_new  = 32'h0;
        b_new  = 32'h0;
        c_new  = 32'h0;
        d_new  = 32'h0;
        e_new  = 32'h0;
        f_new  = 32'h0;
        g_new  = 32'h0;
        h_new  = 32'h0;
        a2h_we = 1'b0;
        if(state_reg == IDLE) begin
            a2h_we = 1'b1;
            //
            if(first_block) begin
                a_new = SHA_H0_0;
                b_new = SHA_H0_1;
                c_new = SHA_H0_2;
                d_new = SHA_H0_3;
                e_new = SHA_H0_4;
                f_new = SHA_H0_5;
                g_new = SHA_H0_6;
                h_new = SHA_H0_7;
            end
            else begin
                a_new = h0_reg;
                b_new = h1_reg;
                c_new = h2_reg;
                d_new = h3_reg;
                e_new = h4_reg;
                f_new = h5_reg;
                g_new = h6_reg;
                h_new = h7_reg;
            end 
        end
        else if(state_reg == ROUNDS) begin
            a_new  = t1 + t2;
            b_new  = a_reg;
            c_new  = b_reg;
            d_new  = c_reg;
            e_new  = d_reg + t1;
            f_new  = e_reg;
            g_new  = f_reg;
            h_new  = g_reg;
            a2h_we = 1'b1;
        end
    end

    //Round counter
    always @(*) begin
        round_cnt_new   = 6'd0;
        round_cnt_we    = 1'b0;

        if(round_rst) begin
            round_cnt_new   = 6'd0;
            round_cnt_we    = 1'b1;
        end
        else if(round_inc) begin
            round_cnt_new   = round_cnt_reg + 6'd1;
            round_cnt_we    = 1'b1;
        end
    end

    //FSM for SHA-256 core
    always @(*) begin
        state = IDLE;

        ready_flag      = 1'b0;

        round_rst       = 1'b0;
        round_inc       = 1'b0;

        first_block     = 1'b0;

        state_update    = 1'b0;

        hash_valid_new  = 1'b0;
        hash_valid_we   = 1'b0;
        case(state_reg)
            IDLE: begin
                ready_flag      = 1'b1;
                hash_valid_we   = 1'b0;
                if(start) begin
                    round_rst       = 1'b1;     //Reset counter before rounds start
                    state           = ROUNDS;
                    state_update    = 1'b1;
                    first_block     = 1'b1;
                    hash_valid_we   = 1'b1;
                    hash_valid_new  = 1'b0;
                end
                if(next) begin
                    round_rst       = 1'b1;     //Reset counter before rounds start
                    state           = ROUNDS;
                    state_update    = 1'b1;
                    hash_valid_we   = 1'b1;
                    hash_valid_new  = 1'b0;
                end
            end
            ROUNDS: begin
                round_inc = 1'b1;
                //When finish 64 rounds (from 0 to 63)
                if(round_cnt_reg == 6'd63) begin
                    state           = DONE;
                    state_update    = 1'b1;
                end 
            end
            DONE: begin
                hash_valid_we   = 1'b1;
                hash_valid_new  = 1'b1;

                state           = IDLE;
                state_update    = 1'b1;
            end

        endcase
    end

endmodule