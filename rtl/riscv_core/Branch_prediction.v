module Branch_prediction(
    input   wire    [2:0]   funct3,
    input   wire    [31:0]  ALU_result,
    input   wire            ZERO,

    output  reg             Branch_taken
);

    always @(*) begin   
        case(funct3)
            3'b000: Branch_taken    = ALU_result[0];          // BEQ
            3'b001: Branch_taken    = ~ALU_result[0];         // BNE
            3'b100: Branch_taken    = ALU_result[0];    // BLT
            3'b101: Branch_taken    = ~ALU_result[0];   // BGE
            3'b110: Branch_taken    = ALU_result[0];    // BLTU
            3'b111: Branch_taken    = ~ALU_result[0];   // BGEU
            default: Branch_taken   = 0;
        endcase
    end 

endmodule