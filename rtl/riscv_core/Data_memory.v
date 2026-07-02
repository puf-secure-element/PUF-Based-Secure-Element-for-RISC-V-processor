module Data_memory(
    input  wire        clk,
    input  wire        MemRead,
    input  wire        MemWrite,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,

    output reg  [31:0] read_data
);

    reg [31:0] mem [0:1023];
    
    integer i;

    initial begin
        for(i = 0; i < 1024; i = i + 1)
            mem[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (MemWrite)
            mem[addr[31:2]] <= write_data;
    end

    always @(*) begin
        if (MemRead)
            read_data = mem[addr[31:2]];
        else
            read_data = 32'b0;
    end

endmodule