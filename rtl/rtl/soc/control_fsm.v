module control_fsm (
    input  wire clk,
    input  wire rst_n,

    // Giao tiếp AXI Reg Bank
    input  wire reg_start,          
    input  wire soft_reset,         // Tín hiệu Soft Reset
    output reg  hw_busy,
    output reg  hw_done_pulse,
    output reg  hw_error_pulse,

    // Giao tiếp Crypto Core
    output reg  puf_start,
    input  wire puf_valid,
    output reg  ecc_start,          
    input  wire ecc_valid,
    output reg  sha_start,          
    input  wire sha_valid,          
    input  wire sha_error,
    output reg  aes_start,
    input  wire aes_done
);

    localparam IDLE      = 4'd0;
    localparam RUN_PUF   = 4'd1;
    localparam WAIT_PUF  = 4'd2;
    localparam RUN_ECC   = 4'd3;
    localparam WAIT_ECC  = 4'd4;
    localparam RUN_SHA   = 4'd5;
    localparam WAIT_SHA  = 4'd6;
    localparam RUN_AES   = 4'd7;
    localparam WAIT_AES  = 4'd8;
    localparam DONE      = 4'd9;
    localparam ERROR     = 4'd10;

    // Timeout (Tính năng 1) - Treo quá 65535 cycles sẽ báo lỗi
    localparam TIMEOUT_MAX = 16'hFFFF; 
    
    reg [3:0] current_state, next_state;
    reg [15:0] timeout_cnt;
    wire timeout_tick = (timeout_cnt == TIMEOUT_MAX);

    // Timeout Counter Logic
    always @(posedge clk) begin
        if (!rst_n || soft_reset || current_state == IDLE || next_state != current_state) begin
            timeout_cnt <= 16'd0;
        end else if (current_state == WAIT_PUF || current_state == WAIT_ECC || 
                     current_state == WAIT_SHA || current_state == WAIT_AES) begin
            timeout_cnt <= timeout_cnt + 1'b1;
        end
    end

    // 1. State Register
    always @(posedge clk) begin
        if (!rst_n || soft_reset) current_state <= IDLE;
        else                      current_state <= next_state;
    end

    // 2. Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE:     if (reg_start) next_state = RUN_PUF;
            RUN_PUF:  next_state = WAIT_PUF; 
            WAIT_PUF: begin
                      if (timeout_tick) next_state = ERROR;
                      else if (puf_valid) next_state = RUN_ECC;
            end
            RUN_ECC:  next_state = WAIT_ECC;
            WAIT_ECC: begin
                      if (timeout_tick) next_state = ERROR;
                      else if (ecc_valid) next_state = RUN_SHA;
            end
            RUN_SHA:  next_state = WAIT_SHA;
            WAIT_SHA: begin
                      if (timeout_tick || sha_error) next_state = ERROR;
                      else if (sha_valid) next_state = RUN_AES;
            end
            RUN_AES:  next_state = WAIT_AES;
            WAIT_AES: begin
                      if (timeout_tick) next_state = ERROR;
                      else if (aes_done) next_state = DONE;
            end
            DONE:     next_state = IDLE; 
            ERROR:    next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // 3. Output Logic
    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            hw_busy        <= 1'b0;
            hw_done_pulse  <= 1'b0;
            hw_error_pulse <= 1'b0;
            puf_start      <= 1'b0;
            ecc_start      <= 1'b0;
            sha_start      <= 1'b0;
            aes_start      <= 1'b0;
        end else begin
            hw_done_pulse  <= 1'b0;
            hw_error_pulse <= 1'b0;
            puf_start      <= 1'b0;
            ecc_start      <= 1'b0;
            sha_start      <= 1'b0;
            aes_start      <= 1'b0;

            case (next_state)
                IDLE:    hw_busy <= 1'b0;
                RUN_PUF: begin hw_busy <= 1'b1; puf_start <= 1'b1; end
                RUN_ECC: ecc_start <= 1'b1;
                RUN_SHA: sha_start <= 1'b1;
                RUN_AES: aes_start <= 1'b1;
                DONE:    begin hw_done_pulse <= 1'b1; hw_busy <= 1'b0; end // Sửa bug busy drop
                ERROR:   begin hw_error_pulse <= 1'b1; hw_busy <= 1'b0; end
                default: ; 
            endcase
        end
    end
endmodule