module challenge_mapper #(
    parameter int CHALLENGE_W = 16,
    parameter int NUM_RO_BITS = 6 // Log2 của 64 RO
)(
    input  logic [CHALLENGE_W-1:0] challenge,
    input  logic [9:0]             pair_cnt,
    
    output logic [NUM_RO_BITS-1:0] idx_a,
    output logic [NUM_RO_BITS-1:0] idx_b
);

    logic [NUM_RO_BITS-1:0] base_a, base_b;

    always_comb begin
        // Base mapping đảm bảo Uniformity
        base_a = pair_cnt[5:0];
        base_b = {pair_cnt[2:0], pair_cnt[8:6]} ^ 6'b101010; 

        // Tùy biến theo Challenge (ví dụ cho Challenge 16-bit)
        idx_a = base_a ^ challenge[5:0];
        idx_b = base_b ^ challenge[11:6];

        // Xử lý Collision (Chống self-compare)
        if (idx_a == idx_b) begin
            idx_b = idx_a ^ challenge[15:12] ^ 6'b000001; 
        end
    end

endmodule