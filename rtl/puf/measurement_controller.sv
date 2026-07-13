module measurement_controller #(
    parameter int WINDOW_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Control
    input  logic                    start,
    input  logic [WINDOW_WIDTH-1:0] measure_window,

    // Outputs
    output logic                    ro_enable,
    output logic                    counter_reset, 
    output logic                    snapshot,
    output logic                    done
);

    typedef enum logic [2:0] {
        ST_IDLE      = 3'd0,
        ST_RESET     = 3'd1,
        ST_MEASURE   = 3'd2,
        ST_FREEZE    = 3'd3,
        ST_SNAPSHOT  = 3'd4,
        ST_DONE      = 3'd5
    } state_t;

    state_t current_state, next_state;
    logic [WINDOW_WIDTH-1:0] measure_cnt;

    // State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) current_state <= ST_IDLE;
        else       current_state <= next_state;
    end

    // Measurement Counter Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            measure_cnt <= '0;
        end else begin
            case(current_state)
                ST_RESET:   measure_cnt <= '0;
                ST_MEASURE: measure_cnt <= measure_cnt + 1'b1;
                default:    measure_cnt <= measure_cnt;
            endcase
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            ST_IDLE: 
                if(start) next_state = ST_RESET;
            ST_RESET: 
                next_state = ST_MEASURE;
            ST_MEASURE: begin
                if(measure_window == 0)
                    next_state = ST_FREEZE;
                else if(measure_cnt >= measure_window - 1'b1)
                    next_state = ST_FREEZE;
            end
            ST_FREEZE:   next_state = ST_SNAPSHOT;
            ST_SNAPSHOT: next_state = ST_DONE;
            ST_DONE:     next_state = ST_IDLE;
            default:     next_state = ST_IDLE;
        endcase
    end

    // Output Logic
    always_comb begin
        ro_enable     = 1'b0;
        counter_reset = 1'b0;
        snapshot      = 1'b0;
        done          = 1'b0;

        case(current_state)
            ST_RESET:    counter_reset = 1'b1;
            ST_MEASURE:  ro_enable     = 1'b1;
            ST_FREEZE:   ; // Giữ ro_enable = 0 để dừng RO
            ST_SNAPSHOT: snapshot      = 1'b1;
            ST_DONE:     done          = 1'b1; // Tạo 1 xung pulse
            default: ; 
        endcase
    end

endmodule