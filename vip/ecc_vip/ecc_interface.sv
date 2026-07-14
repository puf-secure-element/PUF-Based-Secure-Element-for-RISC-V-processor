interface ecc_interface;

    logic           clk;
    logic           rst_n;
    logic           mode;
    logic           start;
    logic   [511:0] raw_resp;
    logic   [95:0]  helper_in;
    logic           valid_in;
    logic   [511:0] corr_resp;
    logic   [95:0]  helper_out;
    logic           done;

endinterface