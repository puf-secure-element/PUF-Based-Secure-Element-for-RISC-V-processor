module axi_to_ahb (
    input  wire         clk,
    input  wire         rst_n,

    // ============================================================
    // AXI4-Lite Slave Interface
    // ============================================================
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,

    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,

    output reg  [1:0]   s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,

    output reg  [31:0]  s_axi_rdata,
    output reg  [1:0]   s_axi_rresp,
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready,

    // ============================================================
    // AHB-Lite Master Interface
    // ============================================================
    output reg  [9:0]   m_HADDR,
    output reg  [1:0]   m_HTRANS,
    output wire [2:0]   m_HBURST,
    output wire [2:0]   m_HSIZE,
    output wire [3:0]   m_HPROT,
    output reg          m_HWRITE,
    output reg          m_HSEL,
    output reg  [31:0]  m_HWDATA,

    input  wire         m_HREADYOUT,
    input  wire [31:0]  m_HRDATA,
    input  wire         m_HRESP
);

    assign m_HBURST = 3'b000;      // SINGLE
    assign m_HSIZE  = 3'b010;      // 32-bit
    assign m_HPROT  = 4'b0011;

    localparam S_IDLE   = 4'd0;
    localparam S_W_ADDR = 4'd1;
    localparam S_W_DATA = 4'd2;
    localparam S_W_WAIT = 4'd3;
    localparam S_W_RESP = 4'd4;
    localparam S_R_ADDR = 4'd5;
    localparam S_R_DATA = 4'd6;
    localparam S_R_WAIT = 4'd7;
    localparam S_R_RESP = 4'd8;

    reg [3:0]  state;
    reg [31:0] addr_reg;
    reg [31:0] data_reg;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state         <= S_IDLE;

            m_HADDR       <= 10'h0;
            m_HTRANS      <= 2'b00;
            m_HWRITE      <= 1'b0;
            m_HSEL        <= 1'b0;
            m_HWDATA      <= 32'h0;

            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;

            addr_reg      <= 32'h0;
            data_reg      <= 32'h0;
        end

        else begin

            // Ready strobes are single-cycle by default
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_arready <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid && m_HREADYOUT) begin
                        addr_reg      <= s_axi_awaddr;
                        data_reg      <= s_axi_wdata;
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        state         <= S_W_ADDR;
                    end
                    else if (s_axi_arvalid && m_HREADYOUT) begin
                        addr_reg      <= s_axi_araddr;
                        s_axi_arready <= 1'b1;
                        state         <= S_R_ADDR;
                    end
                end

                // ---------- write ----------

                S_W_ADDR: begin
                    m_HADDR  <= addr_reg[9:0];
                    m_HWRITE <= 1'b1;
                    m_HTRANS <= 2'b10;   // NONSEQ
                    m_HSEL   <= 1'b1;
                    state    <= S_W_DATA;
                end

                S_W_DATA: begin
                    m_HADDR  <= 10'h0;
                    m_HWRITE <= 1'b0;
                    m_HTRANS <= 2'b00;   // IDLE
                    m_HSEL   <= 1'b0;
                    m_HWDATA <= data_reg;
                    state    <= S_W_WAIT;
                end

                S_W_WAIT: begin
                    if (m_HREADYOUT) begin
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= m_HRESP ? 2'b10 : 2'b00;
                        state        <= S_W_RESP;
                    end
                end

                S_W_RESP: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state        <= S_IDLE;
                    end
                end

                // ---------- read ----------

                S_R_ADDR: begin
                    m_HADDR  <= addr_reg[9:0];
                    m_HWRITE <= 1'b0;
                    m_HTRANS <= 2'b10;   // NONSEQ
                    m_HSEL   <= 1'b1;
                    state    <= S_R_DATA;
                end

                S_R_DATA: begin
                    m_HADDR  <= 10'h0;
                    m_HTRANS <= 2'b00;   // IDLE
                    m_HSEL   <= 1'b0;
                    state    <= S_R_WAIT;
                end

                S_R_WAIT: begin
                    if (m_HREADYOUT) begin
                        s_axi_rdata  <= m_HRDATA;
                        s_axi_rresp  <= m_HRESP ? 2'b10 : 2'b00;
                        s_axi_rvalid <= 1'b1;
                        state        <= S_R_RESP;
                    end
                end

                S_R_RESP: begin
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        state        <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;

            endcase

        end

    end

endmodule