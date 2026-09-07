module baud_generator ( input wire clk,
                        input wire resetn,
                        input wire enable,
                        input wire [15:0] divisor,
                        output reg bclk);

  reg [15:0] count;
  wire [15:0] divisor_tmp; 

  // Added to fixed bug
  reg [15:0] stored_value;
  reg [15:0] previous_value;
  reg change_detected;

  assign divisor_tmp = divisor - 1;

  always @(posedge clk or negedge resetn)
    begin
      if(resetn == 0)
        count <= 0;
      else if(enable)
        if(count == divisor_tmp | change_detected)
          count <= 0;
        else
          count <= count + 1;
      else 
        count <= count;
    end
  
  always @(posedge clk or negedge resetn)
    begin
      if(resetn == 0)
        bclk <= 0;
      else if(count == divisor_tmp)
        bclk <= 1'b1;
      else
        bclk <= 1'b0;
    end

  // Fixed Bug Added to detect value change, revision 2.1
  always @(posedge clk or negedge resetn)
    begin
      if(resetn == 0) begin
        stored_value    <= 16'h0000;
        previous_value  <= 16'h0000;
        change_detected <= 1'b0;
      end
      else begin
        if(divisor != previous_value) begin
          stored_value <= divisor;
          change_detected <= 1'b1;
        end
        else begin
          change_detected <= 1'b0;
        end
        previous_value <= divisor;
      end
    end
endmodule

