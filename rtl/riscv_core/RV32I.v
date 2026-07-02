module rv32_old(
    input wire clk,
    input wire rst_n
);

    //================= Internal Signals =================//
    wire [31:0] Instruction;
    wire RegWrite, MemRead, MemToReg, MemWrite, Branch, Jump, ALUSrc1, ALUSrc2, LUI;
    wire ZERO;

    wire [6:0] opcode;
    wire [2:0] ALUOp;
    wire [3:0] ALUControl;

    wire [31:0] immediate_raw, immediate;
    wire [31:0] ALU_result;
    wire [31:0] operand_1, operand_2;
    wire Branch_taken;
    wire [31:0] pc;

    wire Stall, Flush;
    wire [31:0] ALU_A, ALU_B;

    wire [2:0] funct3;
    wire [31:0] write_data;
    wire [31:0] mem_data;
    wire [31:0] pc_plus4;

    wire [2:0] imm_type;
    wire [1:0] ForwardA, ForwardB;

    wire [31:0] forwardA_data, forwardB_data;
    wire hazard_stall;
    wire ID_Flush;

    //================= IF/ID =================//
    reg [31:0] IF_ID_pc;
    reg [31:0] IF_ID_Instruction;

    //================= ID/EX =================//
    reg ID_EX_RegWrite;
    reg [4:0] ID_EX_rd;
    reg [31:0] ID_EX_pc;
    reg [4:0] ID_EX_rs1;
    reg [4:0] ID_EX_rs2;
    reg [31:0] ID_EX_rv1;
    reg [31:0] ID_EX_rv2;
    reg [31:0] ID_EX_imm;
    reg [6:0] ID_EX_funct7;
    reg [2:0] ID_EX_funct3, ID_EX_ALUOp;
    reg ID_EX_Mem_Read, ID_EX_Mem_Write, ID_EX_Mem_To_Reg;
    reg ID_EX_Branch, ID_EX_Jump, ID_EX_ALUSrc1, ID_EX_ALUSrc2, ID_EX_LUI;

    //================= EX/MEM =================//
    reg [31:0] EX_MEM_imm;
    reg [31:0] EX_MEM_pc_plus;
    reg EX_MEM_Jump, EX_MEM_LUI;
    reg EX_MEM_RegWrite;
    reg [4:0] EX_MEM_rd;
    reg EX_MEM_Mem_Read, EX_MEM_Mem_Write, EX_MEM_Mem_To_Reg;
    reg [2:0] EX_MEM_funct3;
    reg [31:0] EX_MEM_rv2;
    reg [31:0] EX_MEM_ALU_result;

    //================= MEM/WB =================//
    reg [31:0] MEM_WB_imm;
    reg [31:0] MEM_WB_pc_plus;
    reg MEM_WB_Jump, MEM_WB_LUI;
    reg MEM_WB_RegWrite;
    reg [4:0] MEM_WB_rd;
    reg MEM_WB_Mem_To_Reg;
    reg [31:0] MEM_WB_mem_data;
    reg [31:0] MEM_WB_ALU_result;

    //================= Assign =================//
    assign Flush = Branch_taken || ID_EX_Jump;
    assign Stall = hazard_stall;

    assign opcode = IF_ID_Instruction[6:0];
    assign funct3 = IF_ID_Instruction[14:12];

    assign forwardA_data =
        (ForwardA == 2'b00) ? ID_EX_rv1 :
        (ForwardA == 2'b10) ? EX_MEM_ALU_result :
        (ForwardA == 2'b01) ? write_data :
                             ID_EX_rv1;

    assign forwardB_data =
        (ForwardB == 2'b00) ? ID_EX_rv2 :
        (ForwardB == 2'b10) ? EX_MEM_ALU_result :
        (ForwardB == 2'b01) ? write_data :
                             ID_EX_rv2;

    assign pc_plus4 = ID_EX_pc + 32'd4;

    assign write_data =
        (MEM_WB_Mem_To_Reg) ? MEM_WB_mem_data :
        (MEM_WB_Jump)       ? MEM_WB_pc_plus :
        (MEM_WB_LUI)        ? MEM_WB_imm :
                             MEM_WB_ALU_result;

    assign ALU_A = (ID_EX_ALUSrc1) ? ID_EX_pc : forwardA_data;
    assign ALU_B = (ID_EX_ALUSrc2) ? ID_EX_imm : forwardB_data;

    //================= IF/ID =================//
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IF_ID_pc <= 32'b0;
            IF_ID_Instruction <= 32'b0;
        end
        else if (Flush) begin
            IF_ID_pc <= 32'b0;
            IF_ID_Instruction <= 32'h0000_0013; // NOP
        end
        else if (!Stall) begin
            IF_ID_pc <= pc;
            IF_ID_Instruction <= Instruction;
        end
    end

    //================= ID/EX =================//
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_rs1 <= 5'b0;
            ID_EX_rs2 <= 5'b0;
            ID_EX_rd  <= 5'b0;
            ID_EX_pc  <= 32'b0;
            ID_EX_rv1 <= 32'b0;
            ID_EX_rv2 <= 32'b0;
            ID_EX_imm <= 32'b0;
            ID_EX_funct3 <= 3'b0;
            ID_EX_ALUOp  <= 3'b0;
            ID_EX_Mem_Read <= 0;
            ID_EX_Mem_Write <= 0;
            ID_EX_Mem_To_Reg <= 0;
            ID_EX_Branch <= 0;
            ID_EX_Jump <= 0;
            ID_EX_ALUSrc1 <= 0;
            ID_EX_ALUSrc2 <= 0;
            ID_EX_LUI <= 0;
            ID_EX_funct7 <= 7'b0;
            ID_EX_RegWrite <= 0;
        end
        else if (Stall || ID_Flush) begin
            ID_EX_RegWrite <= 0;
            ID_EX_Mem_Read <= 0;
            ID_EX_Mem_Write <= 0;
            ID_EX_Branch <= 0;
            ID_EX_Jump <= 0;
            ID_EX_ALUSrc1 <= 0;
            ID_EX_ALUSrc2 <= 0;
            ID_EX_LUI <= 0;
            ID_EX_ALUOp <= 3'b000;
        end
        else begin
            ID_EX_rs1 <= IF_ID_Instruction[19:15];
            ID_EX_rs2 <= IF_ID_Instruction[24:20];
            ID_EX_rd  <= IF_ID_Instruction[11:7];
            ID_EX_pc  <= IF_ID_pc;
            ID_EX_rv1 <= operand_1;
            ID_EX_rv2 <= operand_2;
            ID_EX_imm <= immediate;
            ID_EX_funct3 <= funct3;
            ID_EX_ALUOp <= ALUOp;
            ID_EX_Mem_Read <= MemRead;
            ID_EX_Mem_Write <= MemWrite;
            ID_EX_Mem_To_Reg <= MemToReg;
            ID_EX_Branch <= Branch;
            ID_EX_Jump <= Jump;
            ID_EX_ALUSrc1 <= ALUSrc1;
            ID_EX_ALUSrc2 <= ALUSrc2;
            ID_EX_LUI <= LUI;
            ID_EX_funct7 <= IF_ID_Instruction[31:25];
            ID_EX_RegWrite <= RegWrite;
        end
    end

    //================= EX/MEM =================//
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_Mem_Read <= 0;
            EX_MEM_Mem_Write <= 0;
            EX_MEM_Mem_To_Reg <= 0;
            EX_MEM_ALU_result <= 0;
            EX_MEM_rd <= 0;
            EX_MEM_RegWrite <= 0;
            EX_MEM_rv2 <= 0;
            EX_MEM_pc_plus <= 0;
            EX_MEM_imm <= 0;
            EX_MEM_Jump <= 0;
            EX_MEM_LUI <= 0;
        end
        else begin
            EX_MEM_Mem_Read <= ID_EX_Mem_Read;
            EX_MEM_Mem_Write <= ID_EX_Mem_Write;
            EX_MEM_Mem_To_Reg <= ID_EX_Mem_To_Reg;
            EX_MEM_ALU_result <= ALU_result;
            EX_MEM_rd <= ID_EX_rd;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_rv2 <= forwardB_data;
            EX_MEM_pc_plus <= pc_plus4;
            EX_MEM_imm <= ID_EX_imm;
            EX_MEM_Jump <= ID_EX_Jump;
            EX_MEM_LUI <= ID_EX_LUI;
        end
    end

    //================= MEM/WB =================//
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_Mem_To_Reg <= 0;
            MEM_WB_ALU_result <= 0;
            MEM_WB_rd <= 0;
            MEM_WB_RegWrite <= 0;
            MEM_WB_mem_data <= 0;
            MEM_WB_pc_plus <= 0;
            MEM_WB_imm <= 0;
            MEM_WB_Jump <= 0;
            MEM_WB_LUI <= 0;
        end
        else begin
            MEM_WB_rd <= EX_MEM_rd;
            MEM_WB_Mem_To_Reg <= EX_MEM_Mem_To_Reg;
            MEM_WB_ALU_result <= EX_MEM_ALU_result;
            MEM_WB_mem_data <= EX_MEM_Mem_Read ? mem_data : 32'b0;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_pc_plus <= EX_MEM_pc_plus;
            MEM_WB_imm <= EX_MEM_imm;
            MEM_WB_Jump <= EX_MEM_Jump;
            MEM_WB_LUI <= EX_MEM_LUI;
        end
    end

    //================= Modules =================//
    Register_file RF0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(MEM_WB_RegWrite),
        .rs1(IF_ID_Instruction[19:15]),
        .rs2(IF_ID_Instruction[24:20]),
        .rd(MEM_WB_rd),
        .wd(write_data),
        .rv1(operand_1),
        .rv2(operand_2)
    );

    ALU A0 (
        .A(ALU_A),
        .B(ALU_B),
        .ALUControl(ALUControl),
        .ALU_result(ALU_result),
        .ZERO(ZERO)
    );

    Immediate_generator IG0 (
        .Instruction(IF_ID_Instruction),
        .imm_type(imm_type),
        .immediate(immediate_raw)
    );

    Sign_extend SE0 (
        .immediate(immediate_raw),
        .imm_type(imm_type),
        .extended_imm(immediate)
    );

    Control_unit CU0 (
        .opcode(opcode),
        .ALUOp(ALUOp),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .Branch(Branch),
        .Jump(Jump),
        .MemToReg(MemToReg),
        .ALUSrc1(ALUSrc1),
        .ALUSrc2(ALUSrc2),
        .LUI(LUI),
        .imm_type(imm_type)
    );

    ALU_control AC0 (
        .ALUOp(ID_EX_ALUOp),
        .funct3(ID_EX_funct3),
        .funct7(ID_EX_funct7),
        .ALU_control(ALUControl)
    );

    PC PC0 (
        .clk(clk),
        .rst_n(rst_n),
        .Stall(Stall),
        .Branch(ID_EX_Branch),
        .Jump(ID_EX_Jump),
        .Branch_taken(Branch_taken),
        .offset(ID_EX_imm),
        .rs1_data(forwardA_data),
        .pc(pc)
    );

    Branch_prediction BE0 (
        .funct3(ID_EX_funct3),
        .ALU_result(ALU_result),
        .ZERO(ZERO),
        .Branch_taken(Branch_taken)
    );

    Instruction_memory IM0 (
        .pc(pc),
        .Instruction(Instruction)
    );

    Data_memory DM0 (
        .clk(clk),
        .MemRead(EX_MEM_Mem_Read),
        .MemWrite(EX_MEM_Mem_Write),
        .addr(EX_MEM_ALU_result),
        .write_data(EX_MEM_rv2),
        .read_data(mem_data)
    );

    Forwarding_unit FU0 (
        .ID_EX_rs1(ID_EX_rs1),
        .ID_EX_rs2(ID_EX_rs2),
        .EX_MEM_rd(EX_MEM_rd),
        .EX_MEM_RegWrite(EX_MEM_RegWrite),
        .MEM_WB_rd(MEM_WB_rd),
        .MEM_WB_RegWrite(MEM_WB_RegWrite),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    Hazard_detection HD0 (
        .ID_EX_MemRead(ID_EX_Mem_Read),
        .ID_EX_rd(ID_EX_rd),
        .IF_ID_rs1(IF_ID_Instruction[19:15]),
        .IF_ID_rs2(IF_ID_Instruction[24:20]),
        .Stall(hazard_stall),
        .Flush(ID_Flush)
    );

endmodule