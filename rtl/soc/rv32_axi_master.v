module rv32_axi_master (
    input  wire        clk,
    input  wire        rst_n,

    // Giao tiếp với CPU
    input  wire        cpu_req,    
    input  wire        cpu_we,     
    input  wire [31:0] cpu_addr,   
    input  wire [31:0] cpu_wdata,  
    input  wire [3:0]  cpu_wstrb,  
    output reg  [31:0] cpu_rdata,  
    output reg         cpu_ready,  
    output reg         cpu_error,  

    // Giao tiếp AXI4-Lite
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

    localparam IDLE    = 3'd0;
    localparam WR_WAIT = 3'd1;
    localparam WR_RESP = 3'd2;
    localparam RD_ADDR = 3'd3;
    localparam RD_DATA = 3'd4;

    reg [2:0] state;

    // FSM Gộp (Single-Block FSM) - Chống nhiễu và Race Condition tuyệt đối
    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
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
        end else begin
            // Mặc định hạ cờ báo xong cho CPU
            cpu_ready <= 1'b0;
            cpu_error <= 1'b0;

            case (state)
                IDLE: begin
                    if (cpu_req && !cpu_ready) begin
                        if (cpu_we) begin
                            m_axi_awaddr  <= cpu_addr;
                            m_axi_wdata   <= cpu_wdata;
                            m_axi_wstrb   <= cpu_wstrb;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                            state         <= WR_WAIT;
                        end else begin
                            m_axi_araddr  <= cpu_addr;
                            m_axi_arvalid <= 1'b1;
                            state         <= RD_ADDR;
                        end
                    end
                end

                WR_WAIT: begin
                    // Hạ cờ AWVALID nếu Slave đã nhận Address
                    if (m_axi_awready && m_axi_awvalid) m_axi_awvalid <= 1'b0;
                    // Hạ cờ WVALID nếu Slave đã nhận Data
                    if (m_axi_wready && m_axi_wvalid)   m_axi_wvalid  <= 1'b0;

                    // Chuyển trạng thái khi cả Address và Data đều đã được gửi xong (Cờ valid rớt về 0)
                    if ((!m_axi_awvalid || m_axi_awready) && (!m_axi_wvalid || m_axi_wready)) begin
                        m_axi_bready <= 1'b1;
                        state        <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    // Chờ phản hồi ghi từ Slave
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        cpu_ready    <= 1'b1;
                        if (m_axi_bresp == 2'b10) cpu_error <= 1'b1;
                        state        <= IDLE;
                    end
                end

                RD_ADDR: begin
                    // Chờ Slave nhận Address Đọc
                    if (m_axi_arready && m_axi_arvalid) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    // Chờ Slave trả Data về
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        cpu_rdata    <= m_axi_rdata;
                        cpu_ready    <= 1'b1;
                        if (m_axi_rresp == 2'b10) cpu_error <= 1'b1;
                        state        <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule