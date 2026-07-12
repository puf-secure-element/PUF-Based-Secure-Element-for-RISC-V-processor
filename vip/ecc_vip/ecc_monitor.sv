class ecc_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_monitor)

    virtual ecc_interface   ecc_vif;

    uvm_analysis_port #(ecc_transaction) ecc_a_port;

    function new(string name = "ecc_monitor", uvm_component parent);
        super.new(name, parent);
        ecc_a_port = new("ecc_a_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual ecc_interface)::get(this, "", "ecc_vif", ecc_vif))
            `uvm_fatal(get_type_name(), $sformatf("FAILED to get ECC_INTERFACE from uvm_config_db"))
    endfunction

    virtual task run_phase(uvm_phase phase);
        ecc_transaction trans;  

        forever begin
            @(posedge ecc_vif.done);
            trans = ecc_transaction::type_id::create("trans");

            trans.mode     = ecc_vif.mode ?
                            ecc_transaction::RECONSTRUCTION :
                            ecc_transaction::ENROLLMENT;

            trans.response = ecc_vif.corr_resp;
            trans.helper   = ecc_vif.helper_out;

            ecc_a_port.write(trans);
        end
    endtask

endclass