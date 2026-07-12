class ecc_driver extends uvm_driver #(ecc_transaction);
    `uvm_component_utils(ecc_driver)

    virtual ecc_interface ecc_vif;

    function new(string name = "ecc_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual ecc_interface)::get(this, "", "ecc_vif", ecc_vif))
            `uvm_fatal(get_type_name(), $sformatf("FAILED to get ECC_INTERFACE from uvm_config_db"))
    endfunction

    virtual task run_phase(uvm_phase phase);

        wait (ecc_vif.rst_n == 1'b1);

        forever begin
            seq_item_port.get(req);

            //`uvm_info(get_type_name(), $sformatf("DRIVER received transaction: mode=%0s", req.mode.name()), UVM_HIGH)

            drive_ecc(req);

            $cast(rsp, req.clone());
            rsp.set_id_info(req);
            seq_item_port.put(rsp);
        end
    endtask

    task drive_ecc(ecc_transaction trans);
        @(posedge ecc_vif.clk);

        ecc_vif.start       <= 1'b1;    //ENROLLMENT
        ecc_vif.raw_resp    <= trans.response;
        ecc_vif.mode        <= trans.mode;

        @(posedge ecc_vif.clk);

        ecc_vif.start       <= 1'b0;    //RECONSTRUCTION

    endtask

endclass