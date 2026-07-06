module key_expansion (
    input   wire            key_is_ready,
    input   wire [255:0]    key_in,

    output  reg  [127:0]    w_out
);
    integer i;

    reg [31:0] w_t [0:59];
    reg [31:0] w_f [0:59];

    //First 8 words are the key itself
    always @(*) begin
        if(key_is_ready) begin
           for(i = 0; i < 8; i = i + 1) begin
                w_t[7-i] = key_in[255 - i*32 -: 32];
                w_f[7-i] = ~key_in[255 - i*32 -: 32];
            end
        end
    end

    aes_sbox dual_sbox(
        .sbox_in_t(),
        .sbox_in_f(),

        .sbox_out_t(),
        .sbox_out_f()
    );
    

    // CASE 1: i mod 8 == 0
    // temp = RotWord(w[i-1])
    // temp = SubWord(temp)
    // temp = temp XOR Rcon
    // w[i] = w[i-8] XOR temp


    // CASE 2: i mod 8 == 4
    // temp = SubWord(w[i-1])
    // w[i] = w[i-8] XOR temp


    // OTHER CASE
    // w[i] = w[i-8] XOR w[i-1]


endmodule