module PC(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            Stall,

    input   wire            Branch,
    input   wire            Pcsrc,
    input   wire            Jump,
    input   wire            Branch_taken,

    input   wire    [31:0]  offset,
    input   wire    [31:0]  rs1_data,

    output  wire    [31:0]  pc
);

    wire    [31:0]  pc_plus4;
    wire    [31:0]  branch_target;
    wire    [31:0]  jalr_target;
    reg     [31:0]  next_pc, pc_reg;

    assign  pc_plus4        = pc_reg + 32'd4;
    assign  branch_target   = pc_reg + offset;
    assign  jalr_target     = (rs1_data + offset) & ~32'd1;

    always @(*) begin   
        if (Jump && Pcsrc)            
            next_pc = jalr_target;
        else if (Jump)                 
            next_pc = branch_target;
        else if (Branch && Branch_taken)
            next_pc = branch_target;
        else
            next_pc = pc_plus4;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            pc_reg <= 32'h0;
        else if(~Stall)
            pc_reg <= next_pc;
    end

    assign  pc  = pc_reg;

endmodule