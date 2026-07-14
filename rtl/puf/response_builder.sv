module response_builder #(
    parameter int RESPONSE_BITS = 512
)(
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Interface từ Comparator
    input  logic                     bit_valid,
    input  logic                     response_bit,
    
    // Interface ra System
    output logic [RESPONSE_BITS-1:0] response,
    output logic                     response_ready
);

    logic [RESPONSE_BITS-1:0] shift_reg;
    logic [9:0]               bit_count; // Đếm số bit đã nhận (cần 10 bit để đếm đến 512)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg      <= '0;
            response       <= '0;
            response_ready <= 1'b0;
            bit_count      <= '0;
        end else begin
            response_ready <= 1'b0; // Mặc định hạ cờ

            if (bit_valid) begin
                bit_count <= bit_count + 1'b1;

                if (bit_count == RESPONSE_BITS - 1) begin
                    // Chu kỳ cuối: Chốt kết quả, nâng cờ và dọn dẹp
                    response       <= {shift_reg[RESPONSE_BITS-2:0], response_bit};
                    response_ready <= 1'b1;
                    bit_count      <= '0;
                    shift_reg      <= '0; // Reset an toàn và dứt khoát
                end else begin
                    // Các chu kỳ bình thường: Tiếp tục dịch bit
                    shift_reg      <= {shift_reg[RESPONSE_BITS-2:0], response_bit};
                end
            end
        end
    end

endmodule