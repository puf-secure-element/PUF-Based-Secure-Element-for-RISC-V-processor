module axi_to_ahb (
    input  wire         clk,
    input  wire         rst_n,

    // ============================================================
    // AXI4-Lite Slave Interface
    // ============================================================

    // ------------------------------------------------------------
    // Write Address Channel
    // ------------------------------------------------------------
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,

    // ------------------------------------------------------------
    // Write Data Channel
    // ------------------------------------------------------------
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,

    // ------------------------------------------------------------
    // Write Response Channel
    // ------------------------------------------------------------
    output reg  [1:0]   s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,

    // ------------------------------------------------------------
    // Read Address Channel
    // ------------------------------------------------------------
    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,

    // ------------------------------------------------------------
    // Read Data Channel
    // ------------------------------------------------------------
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


    // ============================================================
    // Fixed AHB Configuration
    // ============================================================

    assign m_HBURST = 3'b000;      // SINGLE
    assign m_HSIZE  = 3'b010;      // 32-bit
    assign m_HPROT  = 4'b0011;


    // ============================================================
    // FSM States
    // ============================================================

    localparam S_IDLE       = 4'd0;

    // Write states
    localparam S_W_ADDR     = 4'd1;
    localparam S_W_DATA     = 4'd2;
    localparam S_W_WAIT     = 4'd3;
    localparam S_W_RESP     = 4'd4;

    // Read states
    localparam S_R_ADDR     = 4'd5;
    localparam S_R_WAIT     = 4'd6;
    localparam S_R_RESP     = 4'd7;


    reg [3:0] state;


    // ============================================================
    // AXI Write Buffers
    // ============================================================

    reg        addr_valid;
    reg        data_valid;

    reg [31:0] addr_reg;
    reg [31:0] data_reg;


    // ============================================================
    // AHB Response Registers
    // ============================================================

    reg        resp_error;
    reg [31:0] rdata_reg;


    // ============================================================
    // Main Sequential Logic
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state <= S_IDLE;

            m_HADDR  <= 10'h0;
            m_HTRANS <= 2'b00;
            m_HWRITE <= 1'b0;
            m_HSEL   <= 1'b0;
            m_HWDATA <= 32'h0;

        end

        else begin

            case (state)

                // ============================================
                // IDLE
                // ============================================

                S_IDLE: begin

                    if ((s_axi_awaddr != 32'h0) && m_HREADYOUT) begin

                        state <= S_W_ADDR;

                    end

                end


                // ============================================
                // AHB ADDRESS PHASE
                // ============================================

                S_W_ADDR: begin

                    m_HADDR  <= s_axi_awaddr[9:0];
                    m_HWRITE <= 1'b1;
                    m_HTRANS <= 2'b10;   // NONSEQ
                    m_HSEL   <= 1'b1;

                    m_HWDATA <= 32'h0;

                    state <= S_W_DATA;

                end


                // ============================================
                // AHB DATA PHASE
                // ============================================

                S_W_DATA: begin

                    // Match với task ahb_write
                    m_HADDR  <= 10'h0;
                    m_HWRITE <= 1'b0;
                    m_HTRANS <= 2'b00;   // IDLE
                    m_HSEL   <= 1'b0;

                    m_HWDATA <= s_axi_wdata;

                    state <= S_W_WAIT;

                end


                // ============================================
                // WAIT FOR AHB RESPONSE
                // ============================================

                S_W_WAIT: begin

                    if (m_HREADYOUT) begin

                        if (m_HRESP)
                            resp_error <= 1'b1;
                        else
                            resp_error <= 1'b0;

                        state <= S_W_RESP;

                    end

                end


                // ============================================
                // AXI WRITE RESPONSE
                // ============================================

                S_W_RESP: begin

                    s_axi_bvalid <= 1'b1;

                    if (resp_error)
                        s_axi_bresp <= 2'b10; // SLVERR
                    else
                        s_axi_bresp <= 2'b00; // OKAY

                    if (s_axi_bready) begin

                        s_axi_bvalid <= 1'b0;

                        state <= S_IDLE;

                    end

                end


                default: begin

                    state <= S_IDLE;

                end

            endcase

        end

    end

endmodule