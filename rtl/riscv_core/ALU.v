module ALU(
    input   wire    [31:0]  A,      //Operand 1
    input   wire    [31:0]  B,      //Operand 2
    input   wire    [3:0]   ALUControl,  //From ALU control
    
    output  reg     [31:0]  ALU_result,
    output  wire            ZERO
);

    always @(*) begin
        case(ALUControl)
            4'b0000:    ALU_result  = A + B;                        //ADD
            4'b0001:    ALU_result  = A - B;                        //SUB
            4'b0010:    ALU_result  = ($signed(A) < $signed(B));    //Less than
            4'b0011:    ALU_result  = (A < B);                      //Less than unsigned
            4'b0100:    ALU_result  = ($signed(A) > $signed(B));    //Greater than
            4'b0101:    ALU_result  = (A > B);                      //Greater than unsigned
            4'b0110:    ALU_result  = A ^ B;                        //XOR
            4'b0111:    ALU_result  = A | B;                        //OR
            4'b1000:    ALU_result  = A & B;                        //AND
            4'b1001:    ALU_result  = A << B[4:0];                  //Shift Left Logical
            4'b1010:    ALU_result  = A >> B[4:0];                  //Shift Right Logical
            4'b1011:    ALU_result  = $signed(A) >> B[4:0];         //Shift Right Arithmetic
            4'b1100:    ALU_result  = (A == B);                     //Equal
            4'b1101:    ALU_result  = (A != B);                     //Not equal
            4'b1110:    ALU_result  = A + B;                        //PC_plus
            default:    ALU_result  = 32'b0;
        endcase
    end

    assign ZERO = (ALU_result == 0) ? 1'b1 : 1'b0;

endmodule