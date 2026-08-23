module measurement_engine #(
    parameter int NUM_RO        = 64,
    parameter int COUNTER_WIDTH = 24,
    parameter int WINDOW_WIDTH  = 32
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Control Interface
    input  logic                     start,
    input  logic [WINDOW_WIDTH-1:0]  measure_window,
    
    // RO Interface (Nối với ro_bank)
    input  logic [NUM_RO-1:0]        ro_clk,
    output logic                     ro_enable,

    // Output Interface (Nối với tầng xử lý số phía sau)
    output logic                     done,
    output logic [COUNTER_WIDTH-1:0] snapshot_data [NUM_RO]
);

    logic counter_reset;
    logic snapshot_en;
    logic [COUNTER_WIDTH-1:0] raw_count [NUM_RO];

    measurement_controller #(
        .WINDOW_WIDTH(WINDOW_WIDTH)
    ) u_controller (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .measure_window  (measure_window),
        .ro_enable       (ro_enable),
        .counter_reset   (counter_reset),
        .snapshot        (snapshot_en),
        .done            (done)
    );

    counter_bank #(
        .NUM_RO          (NUM_RO),
        .COUNTER_WIDTH   (COUNTER_WIDTH)
    ) u_counter_bank (
        .counter_reset   (counter_reset),
        .ro_clk          (ro_clk),
        .count           (raw_count)
    );

    snapshot_register #(
        .NUM_RO          (NUM_RO),
        .COUNTER_WIDTH   (COUNTER_WIDTH)
    ) u_snapshot (
        .clk             (clk),
        .rst_n           (rst_n),
        .snapshot_en     (snapshot_en),
        .count_in        (raw_count),
        .snapshot_out    (snapshot_data)
    );

endmodule