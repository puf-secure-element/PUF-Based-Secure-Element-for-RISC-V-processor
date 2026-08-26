module key_expansion (
    //input   wire            key_is_ready,
    input   wire [255:0]    key_in,

    output  wire [1919:0]    w_out_t,
    output  wire [1919:0]    w_out_f
);

    wire [31:0] w_t [0:59];
    wire [31:0] w_f [0:59];

    genvar i;

    generate
        for (i = 0; i < 8; i = i + 1) begin : init_key
            // assign w_t[i] = key_is_ready ? key_in[255 - i*32 -: 32] : 32'b0;
            // assign w_f[i] = key_is_ready ? ~key_in[255 - i*32 -: 32] : 32'b0;
            assign w_t[i] = key_in[255 - i*32 -: 32];
            assign w_f[i] = ~key_in[255 - i*32 -: 32];
        end

        for (i = 8; i < 60; i = i + 1) begin : gen_words

            wire [31:0] temp_t, temp_f;

            if ((i % 8) == 0) begin : case_0

                wire [31:0] rot_t = {w_t[i-1][23:0], w_t[i-1][31:24]};
                wire [31:0] rot_f = {w_f[i-1][23:0], w_f[i-1][31:24]};

                wire [31:0] sbox_t, sbox_f;

                sub_bytes aes_sbox_inst (
                    .en         (1'b1),
                    .de         (1'b0),
                    .data_in_t  (rot_t),
                    .data_in_f  (rot_f),
                    .data_out_t (sbox_t),
                    .data_out_f (sbox_f)
                );

                wire [31:0] rcon_val = rcon_func(i/8);
                wire [31:0] rcon_t   = rcon_val;
                wire [31:0] rcon_f   = ~rcon_val;

                assign temp_t = (sbox_t & rcon_f) | (sbox_f & rcon_t);
                assign temp_f = (sbox_t & rcon_t) | (sbox_f & rcon_f);

            end 
            else if ((i % 8) == 4) begin : case_4

                sub_bytes aes_sbox_inst (
                    .en         (1'b1),
                    .de         (1'b0),
                    .data_in_t  (w_t[i-1]),
                    .data_in_f  (w_f[i-1]),
                    .data_out_t (temp_t),
                    .data_out_f (temp_f)
                );

            end 
            else begin : case_other

                assign temp_t = w_t[i-1];
                assign temp_f = w_f[i-1];

            end

            assign w_t[i] = (w_t[i-8] & temp_f) | (w_f[i-8] & temp_t);
            assign w_f[i] = (w_t[i-8] & temp_t) | (w_f[i-8] & temp_f);

        end

        for (i = 0; i < 60; i = i + 1) begin : loop
            assign w_out_t[1919 - i*32 -: 32] = w_t[i];
            assign w_out_f[1919 - i*32 -: 32] = w_f[i];
        end
    endgenerate

    function [31:0] rcon_func;
        input [31:0] r;
        begin
            case(r)
                32'h1: rcon_func = 32'h01000000;
                32'h2: rcon_func = 32'h02000000;
                32'h3: rcon_func = 32'h04000000;
                32'h4: rcon_func = 32'h08000000;
                32'h5: rcon_func = 32'h10000000;
                32'h6: rcon_func = 32'h20000000;
                32'h7: rcon_func = 32'h40000000;
                32'h8: rcon_func = 32'h80000000;
                32'h9: rcon_func = 32'h1b000000;
                32'ha: rcon_func = 32'h36000000;
                default: rcon_func = 32'h00000000;
            endcase
        end
    endfunction

endmodule