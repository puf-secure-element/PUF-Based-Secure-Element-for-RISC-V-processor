class ecc_test extends ecc_base_test;
    `uvm_component_utils(ecc_test)

    ecc_test_sequence ecc_seq;

    function new(string name="ecc_test", uvm_component parent);
        super.new(name,parent);
    endfunction: new

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        
        ecc_seq = ecc_test_sequence::type_id::create("default_seq");
        ecc_seq.start(ecc_env.ecc_agt.seq);

        phase.drop_objection(this);
    endtask

endclass
