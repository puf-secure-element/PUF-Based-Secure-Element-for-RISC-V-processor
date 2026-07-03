module sha256_top(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            sel,
    input   wire            we,

    input   wire [7:0]      addr,
    input   wire [31:0]     wdata,
    output  wire [31:0]     rdata,      //Load data from RISCV instruction
    output  wire            error,
    output  wire [255:0]    hash_out,   //Transfer to AES
    output  wire            hash_valid
);

    integer i;

    parameter   ADDR_CTRL       = 8'h00;
    parameter   ADDR_STATUS     = 8'h04;
    //Block addresses
    parameter   ADDR_BLOCK0     = 8'h10;
    parameter   ADDR_BLOCK15    = 8'h1F;
    //Hash addresses
    parameter   ADDR_HASH0      = 8'h20;
    parameter   ADDR_HASH7      = 8'h27;

    //SHA256 signals
    wire            start, next, done;
    wire [511:0]    data_in;
    reg  [31:0]     tmp_rdata;     

    reg  [31:0]     block_reg [0:15];
    reg  [255:0]    hash_out_reg;
    wire [255:0]    hash_out_tmp;

    reg             start_reg, next_reg, hash_valid_reg;

    assign start = start_reg;
    assign next  = next_reg;
    // assign hash_valid_reg = (sel && we && addr == ADDR_CTRL && (wdata[0] | wdata[1])) ? 1'b0 : 
    //                         hash_valid ? 1'b0 : 
    //                         hash_valid_reg;

    assign rdata    = tmp_rdata;
    assign data_in  = {block_reg[0], block_reg[1], block_reg[2], block_reg[3], block_reg[4], block_reg[5], block_reg[6], block_reg[7], block_reg[8], block_reg[9], block_reg[10], block_reg[11], block_reg[12], block_reg[13], block_reg[14], block_reg[15]};
    assign error    = sel && (addr != ADDR_CTRL) && (addr != ADDR_STATUS) && (addr < ADDR_BLOCK0 || addr > ADDR_BLOCK15) && (addr < ADDR_HASH0 || addr > ADDR_HASH7);
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
            for(i = 0; i < 16; i = i + 1) begin
                block_reg[i] <= 32'b0;
            end
            hash_out_reg     <= 256'b0;
            hash_valid_reg   <= 1'b0;
            tmp_rdata        <= 32'b0;
            
            start_reg        <= 1'b0; 
            next_reg         <= 1'b0; 
        end 
        else begin
            // Default assignments (pulse generation)
            start_reg        <= 1'b0;
            next_reg         <= 1'b0;

            // Hash valid assertion
            if(hash_valid) begin
                hash_out_reg   <= hash_out;
                hash_valid_reg <= 1'b1;
            end

            // Bus Write Logic
            if(sel && we) begin
                if(addr == ADDR_CTRL) begin
                    start_reg <= wdata[0];
                    next_reg  <= wdata[1];
                    
                    if (wdata[0] || wdata[1]) begin
                        hash_valid_reg <= 1'b0;
                    end
                end
                if(addr >= ADDR_BLOCK0 && addr <= ADDR_BLOCK15) begin
                    block_reg[addr[3:0]] <= wdata;
                end
            end 
        end
    end

    always @(*) begin
        tmp_rdata = 32'b0; 
        if (sel && !we) begin
            if (addr >= ADDR_BLOCK0 && addr <= ADDR_BLOCK15) begin
                tmp_rdata = block_reg[addr[3:0]];
            end
            else if (addr >= ADDR_HASH0 && addr <= ADDR_HASH7) begin
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