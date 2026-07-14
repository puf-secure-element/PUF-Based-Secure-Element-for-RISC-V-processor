module testbench;
    import uvm_pkg::*;
    import test_pkg::*;

    ecc_interface ecc_vif();

    ecc_top dut(
        .clk_i(ecc_vif.clk),
        .rst_n_i(ecc_vif.rst_n),
        .mode_i(ecc_vif.mode),
        .start_i(ecc_vif.start),

        .raw_resp_i(ecc_vif.raw_resp),
        .helper_in_i(ecc_vif.helper_in),
        .helper_val_i(ecc_vif.valid_in),

        .helper_out_o(ecc_vif.helper_out),
        .corr_resp_o(ecc_vif.corr_resp),
        .corr_resp_val_o(ecc_vif.done)
    );
    //Reset
    initial begin
        ecc_vif.rst_n = 0;

        repeat(5) @(posedge ecc_vif.clk);

        ecc_vif.rst_n = 1;
    end

    //Create clk
    initial begin
        ecc_vif.clk = 0;
        forever #5 ecc_vif.clk = ~ecc_vif.clk;
    end

    initial begin
        /** Set virtual interface to driver for control, learn detail in next session */
        uvm_config_db#(virtual ecc_interface)::set(null,"*","ecc_vif",ecc_vif);

        /** Start the UVM test */
        run_test();
        

    end

endmodule
