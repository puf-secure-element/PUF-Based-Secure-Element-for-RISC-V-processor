module Branch_prediction(
    input   wire    [2:0]   funct3,
    input   wire    [31:0]  ALU_result,
    input   wire            ZERO,

    output  reg             Branch_taken
);

    always @(*) begin   
        case(funct3)
            // ALU_control already selects a comparison whose result is the
            // branch condition itself, so BNE must NOT be inverted here: the
            // ALU computes (A != B) for it, and negating that again made BNE
            // branch precisely when its operands were EQUAL. That turned the
            // boot firmware's "bne x8,x0 -> error" status check into an
            // unconditional jump to the error path, so the CPU re-issued START
            // forever and never reached the Enroll sender.
            // BGE/BGEU stay inverted, but now over a less-than comparison
            // (see ALU_control.v), since ~(A<B) is exactly A>=B.
            3'b000: Branch_taken    = ALU_result[0];    // BEQ  : A == B
            3'b001: Branch_taken    = ALU_result[0];    // BNE  : A != B
            3'b100: Branch_taken    = ALU_result[0];    // BLT  : A <s B
            3'b101: Branch_taken    = ~ALU_result[0];   // BGE  : ~(A <s B)
            3'b110: Branch_taken    = ALU_result[0];    // BLTU : A <u B
            3'b111: Branch_taken    = ~ALU_result[0];   // BGEU : ~(A <u B)
            default: Branch_taken   = 0;
        endcase
    end 

endmodule