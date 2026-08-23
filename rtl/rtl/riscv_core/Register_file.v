module Register_file(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            en,     //If do not have stall or flush

    input   wire    [4:0]   rs1,    //
    input   wire    [4:0]   rs2,    //
    input   wire    [4:0]   rd,     //
    input   wire    [31:0]  wd,     //Write data

    output  wire    [31:0]  rv1,    //Read value 1
    output  wire    [31:0]  rv2     //Read value 2
);

    reg [31:0]  in_registers    [0:31];     //32 Registers with Width of 32-bits
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i=0; i<32; i=i+1) begin
                in_registers[i]     <= 32'b0;
            end
        end
        else begin
            if(en && (rd != 5'b00000)) begin
                in_registers[rd]    <=  wd; //Write data in into Register at rd address
            end
        end
    end

    assign rv1 = (rs1 == 5'b0)          ?   32'b0 : 
                 ((rs1 == rd) && en)    ?   wd : 
                                            in_registers[rs1];
                 
    assign rv2 = (rs2 == 5'b0)          ?   32'b0 : 
                 ((rs2 == rd) && en)    ?   wd : 
                                            in_registers[rs2];

endmodule