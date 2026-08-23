module ALU_control(
    input   wire    [2:0]   ALUOp,
    input   wire    [2:0]   funct3,
    input   wire    [6:0]   funct7,

    output  reg     [3:0]   ALU_control
);

    always @(*) begin
        casez({ALUOp, funct7[5], funct3})
            {3'b010, 1'b?, 3'b???}, {3'b111, 1'b?, 3'b???}, {3'b100, 1'b?, 3'b???}, {3'b000, 1'b0, 3'b000}, {3'b001, 1'b?, 3'b000}, {3'b110, 1'b?, 3'b???}: ALU_control = 4'b0000;
            {3'b000, 1'b1, 3'b000}: ALU_control = 4'b0001;
            {3'b011, 1'b?, 3'b100}, {3'b001, 1'b?, 3'b010}, {3'b000, 1'b0, 3'b010}: ALU_control = 4'b0010;
            {3'b011, 1'b?, 3'b101}: ALU_control = 4'b0100;
            {3'b011, 1'b?, 3'b110}, {3'b001, 1'b?, 3'b011}, {3'b000, 1'b0, 3'b011}: ALU_control = 4'b0011;
            {3'b011, 1'b?, 3'b111}: ALU_control = 4'b0101;
            {3'b000, 1'b0, 3'b100}, {3'b001, 1'b?, 3'b100}: ALU_control = 4'b0110;
            {3'b000, 1'b0, 3'b110}, {3'b001, 1'b?, 3'b110}: ALU_control = 4'b0111;
            {3'b000, 1'b0, 3'b111}, {3'b001, 1'b?, 3'b111}: ALU_control = 4'b1000;
            {3'b001, 1'b0, 3'b001}, {3'b000, 1'b0, 3'b001}: ALU_control = 4'b1001;
            {3'b001, 1'b0, 3'b101}, {3'b000, 1'b0, 3'b101}: ALU_control = 4'b1010;
            {3'b000, 1'b1, 3'b101}, {3'b001, 1'b1, 3'b101}: ALU_control = 4'b1011;
            {3'b011, 1'b?, 3'b000}: ALU_control = 4'b1100;
            {3'b011, 1'b?, 3'b001}: ALU_control = 4'b1101;
            {3'b101, 1'b?, 3'b???}: ALU_control = 4'b1110;
            default: ALU_control = 4'b0000;
        endcase
    end

endmodule