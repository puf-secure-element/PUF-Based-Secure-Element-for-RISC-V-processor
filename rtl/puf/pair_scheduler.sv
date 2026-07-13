module pair_scheduler #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24,
    parameter int RESPONSE_BITS = 512,
    parameter int CHALLENGE_W   = 16
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Handshake Interface
    input  logic                     start,
    output logic                     busy,

    // Challenge & Data
    input  logic [CHALLENGE_W-1:0]   challenge,
    input  logic [COUNTER_WIDTH-1:0] snapshot_data [NUM_RO],

    // Output to Comparator
    output logic [COUNTER_WIDTH-1:0] count_a,
    output logic [COUNTER_WIDTH-1:0] count_b,
    output logic                     compare_valid
);

    typedef enum logic {
        ST_IDLE    = 1'b0,
        ST_RUNNING = 1'b1
    } state_t;

    state_t current_state, next_state;
    logic [9:0] pair_cnt;
    logic [5:0] idx_a, idx_b;

    // FSM & Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_IDLE;
            pair_cnt      <= '0;
        end else begin
            current_state <= next_state;
            
            if (current_state == ST_IDLE && start) begin
                pair_cnt <= '0;
            end else if (current_state == ST_RUNNING) begin
                pair_cnt <= pair_cnt + 1'b1;
            end
        end
    end

    // Next State
    always_comb begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: 
                if (start) next_state = ST_RUNNING;
            ST_RUNNING: 
                if (pair_cnt == RESPONSE_BITS - 1) next_state = ST_IDLE;
        endcase
    end

    // Instantiate Challenge Mapper (Decoupled Logic)
    challenge_mapper #(
        .CHALLENGE_W(CHALLENGE_W),
        .NUM_RO_BITS(6)
    ) u_mapper (
        .challenge (challenge),
        .pair_cnt  (pair_cnt),
        .idx_a     (idx_a),
        .idx_b     (idx_b)
    );

    // Data Extraction & Outputs
    always_comb begin
        count_a = snapshot_data[idx_a];
        count_b = snapshot_data[idx_b];
    end

    assign compare_valid = (current_state == ST_RUNNING);
    assign busy          = (current_state != ST_IDLE);

endmodule