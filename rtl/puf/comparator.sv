module comparator #(
    parameter int COUNTER_WIDTH = 24
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Interface from Pair Scheduler
    input  logic                     compare_valid, 
    input  logic [COUNTER_WIDTH-1:0] count_a,
    input  logic [COUNTER_WIDTH-1:0] count_b,
    
    // Interface to Response Builder
    output logic                     response_bit,
    output logic                     bit_valid
);

    // Sử dụng thanh ghi (Flip-flop) để Pipeline kết quả, 
    // giúp tối ưu hóa Timing (setup/hold time) cho phép so sánh.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            response_bit <= 1'b0;
            bit_valid    <= 1'b0;
        end else begin
            // Trễ 1 chu kỳ clock so với ngõ vào
            bit_valid <= compare_valid; 
            
            if (compare_valid) begin
                // Nguyên lý cốt lõi của PUF: So sánh tần số
                if (count_a > count_b)
                    response_bit <= 1'b1;
                else
                    response_bit <= 1'b0;
            end
        end
    end

endmodule