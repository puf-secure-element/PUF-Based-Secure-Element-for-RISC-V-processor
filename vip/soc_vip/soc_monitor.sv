class soc_monitor extends uvm_monitor;

    `uvm_component_utils(soc_monitor)

    virtual soc_interface soc_vif;

    uvm_analysis_port #(soc_transaction) soc_export;

    function new(string name = "soc_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);

    endfunction

    virtual task run_phase(uvm_phase phase);

    endtask

endclass