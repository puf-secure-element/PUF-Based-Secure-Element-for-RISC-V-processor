module Hazard_detection(
    input                   ID_EX_MemRead,
    input   wire    [4:0]   ID_EX_rd,
    input   wire    [4:0]   IF_ID_rs1,
    input   wire    [4:0]   IF_ID_rs2,

    output  reg             Stall,
    output  reg             Flush
);

    always @(*) begin
        if(ID_EX_MemRead && (ID_EX_rd != 0) && ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2))) begin
            Stall = 1;
            Flush = 1;
        end
        else begin
            Stall = 0;
            Flush = 0;
        end
    end

endmodule