module response_engine #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24,
    parameter int RESPONSE_BITS = 512,
    parameter int CHALLENGE_W   = 16
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Control & Handshake
    input  logic                     start,
    output logic                     busy,
    
    // Data Inputs
    input  logic [CHALLENGE_W-1:0]   challenge,
    input  logic [COUNTER_WIDTH-1:0] snapshot_data [NUM_RO],

    // Output Interface
    output logic [RESPONSE_BITS-1:0] response,
    output logic                     response_ready
);

    // Internal wires
    logic [COUNTER_WIDTH-1:0] count_a, count_b;
    logic                     compare_valid;
    logic                     response_bit, bit_valid;

    // 1. Pair Scheduler
    pair_scheduler #(
        .NUM_RO(NUM_RO),
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .RESPONSE_BITS(RESPONSE_BITS),
        .CHALLENGE_W(CHALLENGE_W)
    ) u_scheduler (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .busy          (busy),
        .challenge     (challenge),
        .snapshot_data (snapshot_data),
        .count_a       (count_a),
        .count_b       (count_b),
        .compare_valid (compare_valid)
    );

    // 2. Comparator
    comparator #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_comparator (
        .clk           (clk),
        .rst_n         (rst_n),
        .compare_valid (compare_valid),
        .count_a       (count_a),
        .count_b       (count_b),
        .response_bit  (response_bit),
        .bit_valid     (bit_valid)
    );

    // 3. Response Builder (Tự động chốt khi đủ 512 bit)
    response_builder #(
        .RESPONSE_BITS(RESPONSE_BITS)
    ) u_builder (
        .clk            (clk),
        .rst_n          (rst_n),
        .bit_valid      (bit_valid),
        .response_bit   (response_bit),
        .response       (response),
        .response_ready (response_ready)
    );

endmodule