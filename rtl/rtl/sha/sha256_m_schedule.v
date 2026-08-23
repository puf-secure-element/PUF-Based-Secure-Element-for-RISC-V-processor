module sha256_m_schedule (
    input   wire            clk,      
    input   wire            rst_n,
    input   wire [511:0]    block,    
    input   wire            start,
    input   wire            next,
    input   wire [5:0]      round,    

    output  wire [31:0]     w_out
);

    //512 bits split into 16 words of 32 bits each
    //W0, W1, W2, ..., W15 are the first 16 words of the message schedule
    //SHA-256 needs 64 words in total, so we need to compute W16, W17, ..., W63

    integer     i;
    reg         w_we;
    reg [31:0]  w_reg [0:15]; 
    reg [31:0]  w_mem00_new;
    reg [31:0]  w_mem01_new;
    reg [31:0]  w_mem02_new;
    reg [31:0]  w_mem03_new;
    reg [31:0]  w_mem04_new;
    reg [31:0]  w_mem05_new;
    reg [31:0]  w_mem06_new;
    reg [31:0]  w_mem07_new;
    reg [31:0]  w_mem08_new;
    reg [31:0]  w_mem09_new;
    reg [31:0]  w_mem10_new;
    reg [31:0]  w_mem11_new;
    reg [31:0]  w_mem12_new;
    reg [31:0]  w_mem13_new;
    reg [31:0]  w_mem14_new;
    reg [31:0]  w_mem15_new;
    reg [31:0]  w_new;
    reg [31:0]  w_out_reg;
    reg [31:0]  d0;
    reg [31:0]  d1;

    //Wt ​= σ1​(Wt−2​) + Wt−7 ​+ σ0​(Wt−15​) + Wt−16​
    //σ0​(x) = ROTR^7(x) ⊕ ROTR^18(x) ⊕ SHR^3(x)
    //σ1​(x) = ROTR^17(x) ⊕ ROTR^19(x) ⊕ SHR^10(x)

    //Update the message schedule for the next round
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i = 0; i < 16; i = i + 1) begin
                w_reg[i] <= 32'b0;
            end
        end 
        else if(w_we) begin
            w_reg[00] <= w_mem00_new;
            w_reg[01] <= w_mem01_new;
            w_reg[02] <= w_mem02_new;   
            w_reg[03] <= w_mem03_new;
            w_reg[04] <= w_mem04_new;
            w_reg[05] <= w_mem05_new;
            w_reg[06] <= w_mem06_new;
            w_reg[07] <= w_mem07_new;
            w_reg[08] <= w_mem08_new;
            w_reg[09] <= w_mem09_new;
            w_reg[10] <= w_mem10_new;
            w_reg[11] <= w_mem11_new;
            w_reg[12] <= w_mem12_new;
            w_reg[13] <= w_mem13_new;
            w_reg[14] <= w_mem14_new;
            w_reg[15] <= w_mem15_new;
        end 
    end

    always @(*) begin
        w_mem00_new = w_reg[0];
        w_mem01_new = w_reg[1];
        w_mem02_new = w_reg[2];
        w_mem03_new = w_reg[3];
        w_mem04_new = w_reg[4];
        w_mem05_new = w_reg[5];
        w_mem06_new = w_reg[6];
        w_mem07_new = w_reg[7];
        w_mem08_new = w_reg[8];
        w_mem09_new = w_reg[9];
        w_mem10_new = w_reg[10];
        w_mem11_new = w_reg[11];
        w_mem12_new = w_reg[12];
        w_mem13_new = w_reg[13];
        w_mem14_new = w_reg[14];
        w_mem15_new = w_reg[15];
        w_we = 0;
        //σ0​(x) = ROTR^7(x) ⊕ ROTR^18(x) ⊕ SHR^3(x)
        d0  =   {w_reg[1][6:0], w_reg[1][31:7]} ^
                {w_reg[1][17:0], w_reg[1][31:18]} ^
                {3'b000, w_reg[1][31:3]};
        //σ1​(x) = ROTR^17(x) ⊕ ROTR^19(x) ⊕ SHR^10(x)
        d1  =   {w_reg[14][16:0], w_reg[14][31:17]} ^
                {w_reg[14][18:0], w_reg[14][31:19]} ^
                {10'b0000000000, w_reg[14][31:10]};
        //Wt ​= σ1​(Wt−2​) + Wt−7 ​+ σ0​(Wt−15​) + Wt−16​      
        w_new = d1 + w_reg[9] + d0 + w_reg[0];
        if(start) begin
            w_mem00_new = block[511:480];
            w_mem01_new = block[479:448];
            w_mem02_new = block[447:416];
            w_mem03_new = block[415:384];
            w_mem04_new = block[383:352];
            w_mem05_new = block[351:320];
            w_mem06_new = block[319:288];
            w_mem07_new = block[287:256];
            w_mem08_new = block[255:224];
            w_mem09_new = block[223:192];
            w_mem10_new = block[191:160];
            w_mem11_new = block[159:128];
            w_mem12_new = block[127:96];
            w_mem13_new = block[95:64];
            w_mem14_new = block[63:32];
            w_mem15_new = block[31:0];
            w_we    = 1;
        end
        
        if(next && (round > 6'd15)) begin
            //Slide the message schedule window and compute the next word
            w_mem00_new = w_reg[01];
            w_mem01_new = w_reg[02];
            w_mem02_new = w_reg[03];
            w_mem03_new = w_reg[04];
            w_mem04_new = w_reg[05];
            w_mem05_new = w_reg[06];
            w_mem06_new = w_reg[07];
            w_mem07_new = w_reg[08];
            w_mem08_new = w_reg[09];
            w_mem09_new = w_reg[10];
            w_mem10_new = w_reg[11];
            w_mem11_new = w_reg[12];
            w_mem12_new = w_reg[13];
            w_mem13_new = w_reg[14];
            w_mem14_new = w_reg[15];
            w_mem15_new = w_new;
            w_we    = 1;
        end
    end

    always @(*) begin
        if(round < 6'd16) begin
            w_out_reg = w_reg[round[3:0]];
        end
        else begin
            w_out_reg = w_new;
        end
    end

    assign w_out = w_out_reg;

endmodule