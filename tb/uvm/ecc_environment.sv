class ecc_environment extends uvm_env;
  `uvm_component_utils(ecc_environment)

  ecc_agent          ecc_agt;
  ecc_scoreboard     ecc_sb;

  virtual   ecc_interface   ecc_vif;

  function new(string name = "ecc_environment", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info("build_phase", "Entered ....", UVM_HIGH)

    if(!uvm_config_db#(virtual ecc_interface)::get(this, "", "ecc_vif", ecc_vif))
      `uvm_fatal(get_type_name(), $sformatf("FAILED to get ecc_interface from uvm_config_db"))

    ecc_agt = ecc_agent::type_id::create("ecc_agt", this);
    ecc_sb  = ecc_scoreboard::type_id::create("ecc_scoreboard", this);

    uvm_config_db#(virtual ecc_interface)::set(this, "ecc_agt", "ecc_vif", ecc_vif);

    `uvm_info("build_phase", "Existing ....", UVM_HIGH) 
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    ecc_agt.mon.ecc_a_port.connect(ecc_sb.ecc_a_export);
        
  endfunction

endclass