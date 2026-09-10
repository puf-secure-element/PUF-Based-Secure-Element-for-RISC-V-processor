module control_fsm (
    input  wire clk,
    input  wire rst_n,

    // Giao tiếp AXI Reg Bank
    input  wire reg_start,          // Trigger chạy PUF->ECC->SHA (chỉ có tác dụng LẦN ĐẦU, khi key_ready = 0)
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

    // NEW: Key-derivation-once handshake
    // key_ready = 1 sau khi PUF->ECC->SHA chạy xong LẦN ĐẦU TIÊN.
    // Chỉ bị xoá về 0 khi có reset phần cứng (rst_n), soft_reset KHÔNG xoá
    // tín hiệu này -> đảm bảo PUF/ECC/SHA không bao giờ chạy lại lần 2.
    output reg  key_ready,

    // NEW: Bắt tay với khối UART/CPU cho luồng AES lặp lại nhiều lần
    // plaintext_ready: xung 1 chu kỳ báo đã nhận đủ 128-bit plaintext từ UART
    input  wire plaintext_ready,
    input wire enroll_request,
    // uart_tx_valid: xung 1 chu kỳ báo data_out (AES done) đã sẵn sàng để
    // truyền ra UART/software
    output reg  uart_tx_valid,
    output reg enroll_tx_valid,
    output reg enroll_mode,

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
    localparam DONE_KEY  = 4'd7;   // Kết thúc chuỗi derive key (PUF->ECC->SHA)
    localparam RUN_AES   = 4'd8;
    localparam WAIT_AES  = 4'd9;
    localparam DONE_AES  = 4'd10;  // Kết thúc 1 lượt AES -> báo UART lấy data_out
    localparam ERROR     = 4'd11;

    // Timeout (Tính năng 1) - Treo quá 65535 cycles sẽ báo lỗi
    localparam TIMEOUT_MAX = 16'hFFFF; 
    
    reg [3:0] current_state, next_state;
    reg [15:0] timeout_cnt;
    wire timeout_tick = (timeout_cnt == TIMEOUT_MAX);

    // NEW: Latch yêu cầu plaintext_ready cho tới khi FSM thực sự tiêu thụ nó
    // (tránh mất xung nếu plaintext_ready tới đúng lúc FSM chưa rảnh).
    reg plaintext_pending;
    reg enroll_pending;
    reg enroll_active;

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

    // 1b. Key-ready latch - CHỈ reset bằng rst_n, soft_reset không được đụng vào
    // để đảm bảo PUF/ECC/SHA chỉ chạy đúng 1 lần trong suốt vòng đời sau reset.
    always @(posedge clk) begin
        if (!rst_n) key_ready <= 1'b0;
        else if (next_state == DONE_KEY) key_ready <= 1'b1;
    end

    // 1c. Plaintext-pending latch - soft_reset được phép xoá (giống các cờ tạm khác)
    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            plaintext_pending <= 1'b0;
            enroll_pending <= 1'b0;
        end else begin
            if (plaintext_ready) begin
                plaintext_pending <= 1'b1;
            end else if (current_state == IDLE && next_state == RUN_AES) begin
                plaintext_pending <= 1'b0; // đã được FSM tiêu thụ
            end
            if (enroll_request)
                enroll_pending <= 1'b1;
            else if (current_state == IDLE &&
                     (next_state == RUN_PUF || next_state == DONE_KEY))
                enroll_pending <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            enroll_active <= 1'b0;
            enroll_mode <= 1'b0;
        end else if (current_state == IDLE &&
                     (next_state == RUN_PUF || next_state == DONE_KEY)) begin
            enroll_active <= enroll_pending;
            enroll_mode <= enroll_pending ? 1'b0 : 1'b1;
        end else if (current_state == DONE_KEY || current_state == ERROR) begin
            enroll_active <= 1'b0;
            enroll_mode <= 1'b0;
        end
    end

    // 2. Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                  if (enroll_pending && !key_ready)
                      next_state = RUN_PUF;
                  else if (enroll_pending && key_ready)
                      next_state = DONE_KEY;
                  else if (!key_ready && reg_start)
                      next_state = RUN_PUF;              // Chỉ chạy derive key khi CHƯA có key
                      else if (key_ready && plaintext_pending) 
                          next_state = RUN_AES;              // Có key + có plaintext -> chạy AES
                  end
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
                      else if (sha_valid) next_state = DONE_KEY;
            end
            DONE_KEY: next_state = IDLE;
            RUN_AES:  next_state = WAIT_AES;
            WAIT_AES: begin
                      if (timeout_tick) next_state = ERROR;
                      else if (aes_done) next_state = DONE_AES;
            end
            DONE_AES: next_state = IDLE;
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
            uart_tx_valid  <= 1'b0;
            enroll_tx_valid <= 1'b0;
        end else begin
            hw_done_pulse  <= 1'b0;
            hw_error_pulse <= 1'b0;
            puf_start      <= 1'b0;
            ecc_start      <= 1'b0;
            sha_start      <= 1'b0;
            aes_start      <= 1'b0;
            uart_tx_valid  <= 1'b0;
            enroll_tx_valid <= 1'b0;

            case (next_state)
                IDLE:     hw_busy <= 1'b0;
                RUN_PUF:  begin
                    hw_busy <= 1'b1;
                    puf_start <= 1'b1;
                end
                RUN_ECC:  ecc_start <= 1'b1;
                RUN_SHA:  sha_start <= 1'b1;
                DONE_KEY: begin
                    hw_done_pulse <= 1'b1;
                    hw_busy <= 1'b0;
                    if (enroll_active || enroll_pending)
                        enroll_tx_valid <= 1'b1;
                end
                RUN_AES:  begin hw_busy <= 1'b1; aes_start <= 1'b1; end
                DONE_AES: begin hw_done_pulse <= 1'b1; uart_tx_valid <= 1'b1; hw_busy <= 1'b0; end
                ERROR:    begin hw_error_pulse <= 1'b1; hw_busy <= 1'b0; end
                default: ; 
            endcase
        end
    end
endmodule