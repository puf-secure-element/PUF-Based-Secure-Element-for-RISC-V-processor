module sha256_top(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            sel,
    input   wire            we,
    
    //Input value from RISCV to control modules
    input   wire [7:0]      addr,
    input   wire [31:0]     wdata,

    //Input value from ECC
    input   wire [511:0]    ecc_response,
    input   wire            ecc_valid,

    output  wire [31:0]     rdata,      //Load data from RISCV instruction
    output  wire            error,
    output  wire [255:0]    hash_out,   //Transfer to AES
    output  wire            hash_valid
);

    parameter   ADDR_CTRL       = 8'h00;
    parameter   ADDR_STATUS     = 8'h04;
    //Hash addresses
    parameter   ADDR_HASH0      = 8'h20;
    parameter   ADDR_HASH7      = 8'h27;

    //SHA256 signals
    wire            start, next, done;
    wire [511:0]    data_in;
    reg  [31:0]     tmp_rdata;     

    reg  [255:0]    hash_out_reg;
    reg  [511:0]    ecc_reg;
    wire [255:0]    hash_out_tmp;

    reg             start_reg, next_reg, hash_valid_reg;
    
    reg             start_pulse, next_pulse; 

    assign start = start_pulse;
    assign next  = next_pulse;

    assign rdata    = tmp_rdata;
    assign data_in  = ecc_reg;
    assign error    = sel && (addr != ADDR_CTRL) && (addr != ADDR_STATUS) && (addr < ADDR_HASH0 || addr > ADDR_HASH7);
    assign hash_out = hash_valid ? hash_out_tmp : 256'b0;

    sha256 sha256_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .next(next),
        .data_in(data_in),

        .hash_out(hash_out_tmp),
        .hash_valid(hash_valid),
        .done(done)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            hash_out_reg     <= 256'b0;
            hash_valid_reg   <= 1'b0;            
            start_reg        <= 1'b0; 
            next_reg         <= 1'b0; 
            start_pulse      <= 1'b0;
            next_pulse       <= 1'b0;
            ecc_reg          <= 512'b0;
        end 
        else begin
            start_pulse      <= 1'b0;
            next_pulse       <= 1'b0;

            if(hash_valid) begin
                hash_out_reg   <= hash_out_tmp;
                hash_valid_reg <= 1'b1;
            end

            if(sel && we) begin
                if(addr == ADDR_CTRL) begin
                    if (wdata[0]) start_reg <= 1'b1;
                    if (wdata[1]) next_reg  <= 1'b1;
                end
            end 
            
            if (start_reg && ecc_valid) begin
                start_reg <= 1'b0;

                if (ecc_valid && (ecc_response != ecc_reg)) begin
                    ecc_reg        <= ecc_response;   
                    start_pulse    <= 1'b1;
                    hash_valid_reg <= 1'b0;
                end
            end

            if (next_reg) begin
                next_reg <= 1'b0;

                if (ecc_valid && (ecc_response != ecc_reg)) begin
                    ecc_reg         <= ecc_response;
                    next_pulse      <= 1'b1;
                    hash_valid_reg  <= 1'b0;
                end
            end
        end
    end

    always @(*) begin
        tmp_rdata = 32'b0; 
        if (sel && !we) begin

            if (addr >= ADDR_HASH0 && addr <= ADDR_HASH7) begin
                tmp_rdata = hash_out_reg[(7 - (addr - ADDR_HASH0)) * 32 +: 32];
            end
            else begin
                case (addr)
                    ADDR_CTRL:   tmp_rdata = {30'b0, next_reg, start_reg};
                    ADDR_STATUS: tmp_rdata = {30'b0, done, hash_valid_reg};
                    default:     tmp_rdata = 32'b0;
                endcase
            end
        end
    end

endmodule
