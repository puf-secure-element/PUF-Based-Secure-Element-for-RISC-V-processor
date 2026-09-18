module counter_bank #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24
)(
    input  logic                     counter_reset, // Asynchronous Reset từ Controller
    input  logic [NUM_RO-1:0]        ro_clk,
    output logic [COUNTER_WIDTH-1:0] count [NUM_RO]
);

    // NOTE: counter_reset is deliberately sampled SYNCHRONOUSLY here (not as
    // an async reset in the sensitivity list). It's a combinational decode
    // of an FSM state (current_state == ST_RESET) fanning out to all
    // NUM_RO*COUNTER_WIDTH flip-flops below -- with an async sensitivity,
    // Quartus has to treat that fan-out as a clock-class network with no
    // clock constraint on it ("determined to be a clock but was found
    // without an associated clock assignment"), which starves dedicated
    // global routing from other real clocks/resets (incl. rst_n itself,
    // per the "non-dedicated clock routing" warning on KEY[0]) and fails
    // timing closure entirely. Sampling it as ordinary synchronous data
    // avoids all of that; it's safe because ST_RESET is held for a full
    // system clk cycle (20ns @ 50MHz), far longer than one ro_clk[i]
    // period for a 7-inverter ring (well above 50MHz in practice), so a
    // ro_clk edge is guaranteed to land while counter_reset is asserted.
    genvar i;
    generate
        for(i = 0; i < NUM_RO; i++) begin : GEN_COUNTER
            always_ff @(posedge ro_clk[i]) begin
                if(counter_reset)
                    count[i] <= '0;
                else
                    count[i] <= count[i] + 1'b1;
            end
        end
    endgenerate

endmodule