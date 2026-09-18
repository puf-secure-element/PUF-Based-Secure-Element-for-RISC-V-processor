module de10_standard (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR,
    input  wire        UART_RXD,
    output wire        UART_TXD
);

    wire [127:0] data_out;
    wire         irq;
    wire         aes_done;
    wire         manual_tx_fired;
    wire [7:0]   debug_trace;
    wire         rx_block_pulse;

    soc u_soc (
        .clk             (CLOCK_50),
        .rst_n           (KEY[0]),
        .data_out        (data_out),
        .aes_done        (aes_done),
        .uart_rxd        (UART_RXD),
        .uart_txd        (UART_TXD),
        .uart_irq        (irq),
        .manual_tx_fired (manual_tx_fired),
        .debug_trace     (debug_trace),
        .rx_block_pulse  (rx_block_pulse)
    );

    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // Sticky latch: set forever (until KEY0 reset) the first time firmware
    // ever triggers a manual UART send (Enroll response, mem[91..] onward).
    // Bisects "CPU never reached the Enroll code" (this stays dark) from
    // "it triggered a send but the byte never reached the host" (this lights
    // up even if nothing ever showed up on the ESP/listener side).
    reg manual_tx_fired_sticky;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            manual_tx_fired_sticky <= 1'b0;
        else if (manual_tx_fired)
            manual_tx_fired_sticky <= 1'b1;
    end

    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // Free-running counter wired straight to CLOCK_50/KEY[0], with zero
    // dependency on `soc`. Confirmed already: this blinks fine on real
    // hardware, proving board/clock/JTAG/programming are all healthy.
    reg [25:0] diag_counter;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            diag_counter <= 26'd0;
        else
            diag_counter <= diag_counter + 26'd1;
    end

    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // irq/LEDR9 turned out to be a dead end: uart_interrupt.v ANDs every
    // status bit with an "enable" input (en_tx_fifo_full etc.) that only a
    // CPU register write can set, and nothing in Instruction_memory.v's
    // firmware ever writes it -- so interrupt is permanently 0 by design,
    // completely independent of whether UART/CPU/PUF are actually alive.
    // Every LEDR9-based test result so far (PUF bypass, PUF removal,
    // UART-only isolation) was uninformative because of this, not because
    // those subsystems were broken.
    // UART_TXD idles at logic 1 (mark/idle) the moment the transmitter
    // comes out of reset (see uart_transmiter.v: tx_shift_data <= 9'h1 on
    // reset), with no enable-bit gating at all -- a real "is uart_top
    // alive" signal. Mirror it onto LEDR9 so it's visible without a scope.
    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // LEDR[7:0] used to mirror data_out[7:0] (last AES byte), which only
    // ever confirmed something we already know works. Re-purposed as the
    // firmware progress tracer instead -- see Instruction_memory.v for the
    // value table. 0x00 means the firmware never reached its first stamp.
    assign LEDR[7:0] = debug_trace;
    assign LEDR[8]   = diag_counter[25];
    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    // LEDR9 trước đây chốt cứng lần kích manual-TX đầu tiên; việc đó đã chứng
    // minh xong (khung Enroll tới được ESP với CRC đúng). Giờ nó đổi trạng
    // thái mỗi khi FPGA gom đủ MỘT KHỐI 16 BYTE từ host, tức mỗi lần nhận
    // được một nonce. Nhờ vậy phân biệt được hai thứ trước đây nhìn giống hệt
    // nhau khi Auth trả về 0/16: nonce không tới nơi (đèn đứng yên -> lỗi dây
    // ESP TX -> UART_RXD) hay nonce tới mà board không trả lời (đèn đổi ->
    // lỗi nằm trong FPGA).
    reg rx_block_toggle;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])              rx_block_toggle <= 1'b0;
        else if (rx_block_pulse)  rx_block_toggle <= ~rx_block_toggle;
    end
    assign LEDR[9]   = rx_block_toggle;

endmodule