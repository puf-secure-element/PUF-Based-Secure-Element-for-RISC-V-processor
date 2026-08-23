module Instruction_memory(
    input   wire    [31:0]  pc,

    output  wire    [31:0]  Instruction
);

    reg [31:0]  mem [0:1023];

    initial begin
            // --- AES CONTROL = Encrypt ---
    mem[0] = 32'h00800293; // addi x5, x0, 0x08    (x5 = 0x00000008)
    mem[1] = 32'h00200313; // addi x6, x0, 0x02    (x6 = 0x00000002)
    mem[2] = 32'h0062A023; // sw x6, 0(x5)         MEM[0x08] = 0x00000002
    mem[3] = 32'h00000013; // nop
    mem[4] = 32'h00000013; // nop

    // --- ECC MODE = Enrollment ---
    mem[5] = 32'h00C00293; // addi x5, x0, 0x0C    (x5 = 0x0000000C)
    mem[6] = 32'h00000313; // addi x6, x0, 0x00    (x6 = 0x00000000)
    mem[7] = 32'h0062A023; // sw x6, 0(x5)         MEM[0x0C] = 0x00000000
    mem[8] = 32'h00000013; // nop
    mem[9] = 32'h00000013; // nop

    // --- SHA START ---
    mem[10] = 32'h00000293; // addi x5, x0, 0x00    (x5 = 0x00000000)
    mem[11] = 32'h00100313; // addi x6, x0, 0x01    (x6 = 0x00000001)
    mem[12] = 32'h0062A023; // sw x6, 0(x5)         MEM[0x00] = 0x00000001
    mem[13] = 32'h00000013; // nop
    mem[14] = 32'h00000013; // nop

    // --- PUF START ---
    mem[15] = 32'h01000293; // addi x5, x0, 0x10    (x5 = 0x00000010)
    mem[16] = 32'h00100313; // addi x6, x0, 0x01    (x6 = 0x00000001)
    mem[17] = 32'h0062A023; // sw x6, 0(x5)         MEM[0x10] = 0x00000001
    mem[18] = 32'h00000013; // nop
    mem[19] = 32'h00000013; // nop

    // --- END / LOOP ---
    mem[20] = 32'h0000006F; // jal x0, 0          (infinite loop)
    end


    assign  Instruction =   mem[pc[31:2]];  //PC >> 2

endmodule