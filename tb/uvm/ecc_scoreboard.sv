class ecc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ecc_scoreboard)

    uvm_analysis_imp #(ecc_transaction, ecc_scoreboard) ecc_a_export;

    bit [511:0] expected_corr_resp;
    bit         expected_valid = 0;

    function new(string name = "ecc_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ecc_a_export = new("ecc_a_export", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
       
    endtask

    virtual function void write(ecc_transaction trans);
        if (trans.mode == ecc_transaction::ENROLLMENT) begin
            expected_corr_resp = trans.response;
            expected_valid     = 1;
            `uvm_info("ECC_SB",
                $sformatf("Saved expected response = %h", expected_corr_resp), UVM_LOW)
        end
        else begin 
            if (!expected_valid) begin
                `uvm_error("ECC_SB", "===== Expected response has not been enrolled yet! =====")
                return;
            end

            if (trans.response == expected_corr_resp)
                `uvm_info("ECC_SB", "\n\n===== ECC Reconstruction PASSED SUCCESSFULLY =====\n", UVM_LOW)
            else
                `uvm_error("ECC_SB",$sformatf("\n\n===== ECC Reconstruction FAILED !!!!!, Expected = %h, Actual = %h =====\n", expected_corr_resp, trans.response))


        end
    endfunction

endclass