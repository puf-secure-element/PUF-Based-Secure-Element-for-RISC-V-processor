module ro_cell #(
    parameter int ID = 0 // Thêm ID để phân biệt các cell
)(
    input  logic enable,
    output logic ro_out
);

`ifndef SYNTHESIS
    real  delay_ns;
    logic clk_sim;

    initial begin
        clk_sim = 1'b0;
        // Mỗi cell sẽ có delay lệch nhau một chút dựa vào ID.
        // Ví dụ: ID=0 -> 2.00ns, ID=1 -> 2.01ns... ID=63 -> 2.63ns
        delay_ns = 2.0 + (ID * 0.01);
    end

    always begin
        if (enable) begin
            #(delay_ns) clk_sim = ~clk_sim;
        end else begin
            clk_sim = 1'b0;
            wait(enable == 1'b1);
        end
    end

    assign ro_out = clk_sim;

`else
    (* keep = "true", dont_touch = "true" *) logic [6:0] net_chain;
    assign net_chain[0] = ~(enable & net_chain[6]);
    assign net_chain[1] = ~net_chain[0];
    assign net_chain[2] = ~net_chain[1];
    assign net_chain[3] = ~net_chain[2];
    assign net_chain[4] = ~net_chain[3];
    assign net_chain[5] = ~net_chain[4];
    assign net_chain[6] = ~net_chain[5];
    assign ro_out = net_chain[6];
`endif

endmodule