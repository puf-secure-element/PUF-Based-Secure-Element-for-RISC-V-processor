module Sign_extend(
    input   wire    [31:0]  immediate,
    input   wire    [2:0]   imm_type,

    output  reg     [31:0]  extended_imm
);

    always @(*) begin
        case(imm_type)
            //I-type
            3'b001:     extended_imm = {{20{immediate[11]}}, immediate[11:0]};
            //S-type
            3'b010:     extended_imm = {{20{immediate[11]}}, immediate[11:0]};
            //B-type
            3'b011:     extended_imm = {{19{immediate[12]}}, immediate[12:0]};
            //U-type
            3'b100:     extended_imm = immediate;
            //J-type
            3'b101:     extended_imm = {{11{immediate[20]}}, immediate[20:0]};
            default:    extended_imm = 32'b0;
        endcase
    end

endmodule