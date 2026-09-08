module axi_to_ahb (
    input  wire         clk,
    input  wire         rst_n,

    // ---------------- AXI4-Lite slave (from CPU side / interconnect) -------
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

    // ---------------- AHB-Lite master (to uart_top) ------------------------
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

    // Fixed AHB attributes: single 32-bit transfer, no burst.
    assign m_HBURST = 3'b000;
    assign m_HSIZE  = 3'b010;
    assign m_HPROT  = 4'b0011;

    localparam S_IDLE  = 3'd0;
    localparam S_ADDR  = 3'd1; // address phase, exactly 1 cycle
    localparam S_WAIT  = 3'd2; // HTRANS=IDLE, waiting for HREADYOUT
    localparam S_WRESP = 3'd3;
    localparam S_RRESP = 3'd4;

    reg [2:0]  state;
    reg        is_write;
    reg        resp_err;
    reg [31:0] rdata_reg;

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
            s_axi_arready <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
            is_write      <= 1'b0;
            resp_err      <= 1'b0;
            rdata_reg     <= 32'h0;
        end else begin
            // Defaults - pulsed signals drop unless re-asserted below
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_arready <= 1'b0;

            case (state)
                S_IDLE: begin
                    m_HTRANS <= 2'b00;
                    m_HSEL   <= 1'b0;
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        m_HADDR       <= s_axi_awaddr[9:0];
                        m_HWDATA      <= s_axi_wdata;
                        m_HWRITE      <= 1'b1;
                        m_HTRANS      <= 2'b10; // NONSEQ
                        m_HSEL        <= 1'b1;
                        is_write      <= 1'b1;
                        state         <= S_ADDR;
                    end else if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        m_HADDR       <= s_axi_araddr[9:0];
                        m_HWRITE      <= 1'b0;
                        m_HTRANS      <= 2'b10; // NONSEQ
                        m_HSEL        <= 1'b1;
                        is_write      <= 1'b0;
                        state         <= S_ADDR;
                    end
                end

                S_ADDR: begin
                    // Address phase lasted exactly one cycle - drop HTRANS
                    // to IDLE now, keep HADDR/HWRITE/HWDATA/HSEL stable so
                    // the downstream combinational PWDATA path still sees
                    // the right data while we wait for HREADYOUT.
                    m_HTRANS <= 2'b00;
                    state    <= S_WAIT;
                end

                S_WAIT: begin
                    if (m_HREADYOUT) begin
                        m_HSEL   <= 1'b0;
                        resp_err <= m_HRESP;
                        if (is_write) begin
                            state <= S_WRESP;
                        end else begin
                            rdata_reg <= m_HRDATA;
                            state     <= S_RRESP;
                        end
                    end
                end

                S_WRESP: begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp  <= resp_err ? 2'b10 : 2'b00;
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state        <= S_IDLE;
                    end
                end

                S_RRESP: begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rdata  <= rdata_reg;
                    s_axi_rresp  <= resp_err ? 2'b10 : 2'b00;
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        state        <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule