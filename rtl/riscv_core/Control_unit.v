module Control_unit(
    input   wire   [6:0]   opcode,

    output  reg    [2:0]   ALUOp,
    output  reg            RegWrite,
    output  reg            MemRead,
    output  reg            MemWrite,
    output  reg            Branch,
    output  reg            Jump,
    output  reg            MemToReg,
    output  reg            ALUSrc1,
    output  reg            ALUSrc2,
    output  reg            LUI,
    output  reg            Pcsrc,
    output  reg    [2:0]   imm_type
);

    always @(*) begin
        //Initial values
        RegWrite    = 0;
        MemRead     = 0;
        MemToReg    = 0;
        MemWrite    = 0;
        ALUSrc1     = 0;
        ALUSrc2     = 0;
        Branch      = 0;
        Jump        = 0;
        LUI         = 0;
        Pcsrc       = 0;
        ALUOp       = 3'b111;   //NOP
        imm_type    = 3'b000;

        case(opcode)
            7'b0110011: begin   //R-Type
                RegWrite    = 1;
                ALUOp       = 3'b000;
            end
            7'b0010011: begin   //I-Type
                RegWrite    = 1;
                ALUSrc2     = 1;
                ALUOp       = 3'b001;
                imm_type    = 3'b001;
            end
            7'b0000011: begin   //Load
                RegWrite    = 1;
                ALUSrc2     = 1;
                MemRead     = 1;
                MemToReg    = 1;
                ALUOp       = 3'b110;
                imm_type    = 3'b001;
            end
            7'b0100011: begin   //Store
                ALUSrc2     = 1;
                MemWrite    = 1;
                ALUOp       = 3'b010;
                imm_type    = 3'b010;
            end
            7'b1100011: begin   //Branch
                Branch      = 1;
                ALUOp       = 3'b011;
                imm_type    = 3'b011;
            end
            7'b1101111: begin   //JAL
                RegWrite    = 1;
                Jump        = 1;
                ALUSrc1     = 1;
                ALUOp       = 3'b101;
                imm_type    = 3'b101;
            end
            7'b1100111: begin   //JALR
                RegWrite    = 1;
                Jump        = 1;
                ALUSrc1     = 1;
                Pcsrc       = 1;
                ALUOp       = 3'b101;
                imm_type    = 3'b001;
            end
            7'b0110111: begin   //LUI
                RegWrite    = 1;
                ALUSrc1     = 1;
                LUI         = 1;
                ALUOp       = 3'b100;
                imm_type    = 3'b100;
            end
            7'b0010111: begin   //AUIPC
                RegWrite    = 1;
                ALUSrc1     = 1;
                ALUSrc2     = 1;
                ALUOp       = 3'b100;
                imm_type    = 3'b100;
            end
        endcase
    end

endmodule