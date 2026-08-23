module ro_puf_core #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24,
    parameter int WINDOW_WIDTH  = 32,
    parameter int RESPONSE_BITS = 512,
    parameter int CHALLENGE_W   = 16
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // SoC Control Interface (AXI Wrapper sẽ giao tiếp qua đây)
    input  logic                     start,
    input  logic [WINDOW_WIDTH-1:0]  measure_window,
    input  logic [CHALLENGE_W-1:0]   challenge,

    // Output Interface
    output logic [RESPONSE_BITS-1:0] response,
    output logic                     response_ready,
    output logic                     core_busy // Báo cho AXI biết Core đang bận
);

    //------------------------------------------------------------
    // Internal Signals
    //------------------------------------------------------------
    logic [NUM_RO-1:0]        ro_clk;
    logic                     ro_enable;
    
    logic                     meas_start;
    logic                     meas_done;
    logic [COUNTER_WIDTH-1:0] snapshot_data [NUM_RO];

    logic                     resp_start;
    logic                     resp_busy;

    //------------------------------------------------------------
    // Top-Level Orchestrator FSM
    //------------------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE    = 2'd0,
        ST_MEASURE = 2'd1, // Đang đo tần số
        ST_PROCESS = 2'd2  // Đang xử lý số (Scheduler + Builder)
    } top_state_t;

    top_state_t current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= ST_IDLE;
        else        current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;
        
        meas_start = 1'b0;
        resp_start = 1'b0;

        case (current_state)
            ST_IDLE: begin
                if (start) begin
                    meas_start = 1'b1;
                    next_state = ST_MEASURE;
                end
            end

            ST_MEASURE: begin
                // Chờ Measurement Engine đo xong
                if (meas_done) begin
                    resp_start = 1'b1; // Phát lệnh cho Response Engine chạy
                    next_state = ST_PROCESS;
                end
            end

            ST_PROCESS: begin
                // Chỉ cần bắt đúng xung pulse của response_ready là đủ an toàn
                if (response_ready) begin
                    next_state = ST_IDLE;
                end
            end
            
            default: next_state = ST_IDLE;
        endcase
    end

    // Khóa mọi tín hiệu start từ ngoài khi Core không ở trạng thái IDLE
    assign core_busy = (current_state != ST_IDLE);

    //------------------------------------------------------------
    // 1. Physical Layer (Entropy Source)
    //------------------------------------------------------------
    ro_bank #(
        .NUM_RO(NUM_RO)
    ) u_ro_bank (
        .enable (ro_enable),
        .ro_clk (ro_clk)
    );

    //------------------------------------------------------------
    // 2. Measurement Layer
    //------------------------------------------------------------
    measurement_engine #(
        .NUM_RO(NUM_RO),
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .WINDOW_WIDTH(WINDOW_WIDTH)
    ) u_measurement_engine (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (meas_start),   // Điều khiển bởi Top FSM
        .measure_window (measure_window),
        .ro_clk         (ro_clk),
        .ro_enable      (ro_enable),
        .done           (meas_done),
        .snapshot_data  (snapshot_data)
    );

    //------------------------------------------------------------
    // 3. Digital Processing Layer
    //------------------------------------------------------------
    response_engine #(
        .NUM_RO(NUM_RO),
        .COUNTER_WIDTH(COUNTER_WIDTH),
        .RESPONSE_BITS(RESPONSE_BITS),
        .CHALLENGE_W(CHALLENGE_W)
    ) u_response_engine (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (resp_start),   // Điều khiển bởi Top FSM
        .busy           (resp_busy),
        .challenge      (challenge),
        .snapshot_data  (snapshot_data),
        .response       (response),
        .response_ready (response_ready)
    );

endmodule