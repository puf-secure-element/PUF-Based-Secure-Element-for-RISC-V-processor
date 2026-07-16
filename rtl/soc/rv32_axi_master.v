module rv32_axi_master (
    input  wire        clk,
    input  wire        rst_n,

    // =========================================================================
    // NATIVE CPU INTERFACE (Giao tiếp với lõi RV32I)
    // =========================================================================
    input  wire        cpu_req,    // 1: CPU có lệnh đọc/ghi cần thực thi
    input  wire        cpu_we,     // 1: Lệnh Ghi (Store) | 0: Lệnh Đọc (Load)
    input  wire [31:0] cpu_addr,   // Địa chỉ từ CPU
    input  wire [31:0] cpu_wdata,  // Dữ liệu CPU muốn ghi
    input  wire [3:0]  cpu_wstrb,  // Byte enable (4'b1111 cho ghi nguyên word 32-bit)
    output reg  [31:0] cpu_rdata,  // Dữ liệu đọc về trả cho CPU
    output reg         cpu_ready,  // 1: Báo CPU biết giao dịch đã xong, chạy lệnh tiếp theo
    output reg         cpu_error,  // 1: Báo CPU biết có lỗi (SLVERR) từ IP Slave

    // =========================================================================
    // AXI4-LITE MASTER INTERFACE
    // =========================================================================
    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,
    
    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);

    // FSM States
    localparam IDLE       = 3'd0;
    localparam WR_WAIT    = 3'd1;  // Chờ Slave nhận Address và Data
    localparam WR_RESP    = 3'd2;  // Chờ Slave gửi phản hồi (B-Channel)
    localparam RD_ADDR    = 3'd3;  // Chờ Slave nhận Address
    localparam RD_DATA    = 3'd4;  // Chờ Slave trả Data (R-Channel)

    reg [2:0] state, next_state;

    // Cờ phụ trợ cho kênh Ghi (độc lập AW và W)
    reg aw_done;
    reg w_done;

    // State Register
    always @(posedge clk) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (cpu_req) begin
                    if (cpu_we) next_state = WR_WAIT;
                    else        next_state = RD_ADDR;
                end
            end
            
            WR_WAIT: begin
                // Chuyển sang đợi B-Resp khi CẢ HAI kênh AW và W đều đã gửi xong
                if ((aw_done || (m_axi_awvalid && m_axi_awready)) && 
                    (w_done  || (m_axi_wvalid  && m_axi_wready))) begin
                    next_state = WR_RESP;
                end
            end
            
            WR_RESP: begin
                if (m_axi_bvalid && m_axi_bready) next_state = IDLE;
            end
            
            RD_ADDR: begin
                if (m_axi_arvalid && m_axi_arready) next_state = RD_DATA;
            end
            
            RD_DATA: begin
                if (m_axi_rvalid && m_axi_rready) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output & Control Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            m_axi_awaddr  <= 32'h0;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata   <= 32'h0;
            m_axi_wstrb   <= 4'h0;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_araddr  <= 32'h0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            
            cpu_rdata     <= 32'h0;
            cpu_ready     <= 1'b0;
            cpu_error     <= 1'b0;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
        end else begin
            // Xóa mặc định xung ready trả về cho CPU
            cpu_ready <= 1'b0;
            cpu_error <= 1'b0;

            case (state)
                IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (cpu_req && !cpu_ready) begin
                        if (cpu_we) begin
                            // Đẩy Address và Data lên AXI cùng lúc
                            m_axi_awaddr  <= cpu_addr;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= cpu_wdata;
                            m_axi_wstrb   <= cpu_wstrb;
                            m_axi_wvalid  <= 1'b1;
                        end else begin
                            m_axi_araddr  <= cpu_addr;
                            m_axi_arvalid <= 1'b1;
                        end
                    end
                end

                WR_WAIT: begin
                    // Nếu Slave đã nhận Address thì hạ AWVALID (Chống gửi đúp)
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        aw_done       <= 1'b1;
                    end
                    // Nếu Slave đã nhận Data thì hạ WVALID
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        w_done       <= 1'b1;
                    end
                    
                    // Chuẩn bị mở kênh BREADY để đón kết quả
                    if (next_state == WR_RESP) begin
                        m_axi_bready <= 1'b1;
                    end
                end

                WR_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        cpu_ready    <= 1'b1; // Báo CPU lệnh Store đã xong
                        if (m_axi_bresp == 2'b10) cpu_error <= 1'b1; // Bắt SLVERR
                    end
                end

                RD_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1; // Mở kênh RREADY đón Data
                    end
                end

                RD_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        cpu_rdata    <= m_axi_rdata; // Chốt dữ liệu về cho CPU
                        cpu_ready    <= 1'b1;        // Báo CPU lệnh Load đã xong
                        if (m_axi_rresp == 2'b10) cpu_error <= 1'b1; // Bắt SLVERR
                    end
                end
            endcase
        end
    end

endmodule