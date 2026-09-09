module uart_fifo (input wire pclk,
                  input wire presetn,
                  input wire wr,
                  input wire rd,
                  input wire [7:0] data_in,
                  output wire [7:0] data_out,
                  output wire fifo_full,
                  output wire fifo_empty);

  reg[4:0] wptr,rptr;   
  reg[7:0] mem[15:0];

  assign fifo_we = (~fifo_full)  & wr;
  assign fifo_rd = (~fifo_empty) & rd;
  assign fbit_comp = wptr[4] ^ rptr[4];
  assign pointer_equal = (wptr[3:0] - rptr[3:0]) ? 0:1;

  assign fifo_full  =  fbit_comp & pointer_equal;  
  assign fifo_empty = (~fbit_comp) & pointer_equal;

  // Write pointer
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        wptr <= 5'b00000;
      else if(fifo_we) 
        wptr <= wptr + 5'b00001; 
      else 
        wptr <= wptr;
    end
  
  // Read pointer
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        rptr <= 5'b00000;
      else if(fifo_rd)
        rptr <= rptr + 5'b00001; 
      else 
        rptr <= rptr;
    end

  // Memory
  always @(posedge pclk)
    begin
      if(fifo_we) begin
        mem[wptr[3:0]] <= data_in;
      end
    end
  assign data_out = mem[rptr[3:0]];   
  
endmodule
