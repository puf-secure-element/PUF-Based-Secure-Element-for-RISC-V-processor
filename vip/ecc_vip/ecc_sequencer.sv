class ecc_sequencer extends uvm_sequencer #(ecc_transaction);
    `uvm_component_utils(ecc_sequencer)

    local string msg = "[ECC_VIP][ECC_SEQUENCER]";

    function new(string name = "ecc_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction

endclass