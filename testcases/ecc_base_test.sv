class ecc_base_test extends uvm_test;
  `uvm_component_utils(ecc_base_test)

  ecc_environment           ecc_env;
  virtual ecc_interface     ecc_vif;

  function new(string name="ecc_base_test", uvm_component parent);
    super.new(name,parent);
  endfunction: new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual ecc_interface)::get(this, "", "ecc_vif", ecc_vif)) begin
      `uvm_fatal("ecc_base_test",$sformatf("FAILED to get ecc_vif from uvm_config_db"))
    end
    
    ecc_env = ecc_environment::type_id::create("ecc_env",this);

    uvm_config_db#(virtual ecc_interface)::set(this, "ecc_env", "ecc_vif", ecc_vif);
   
  endfunction: build_phase
  
  virtual function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info("start_of_simulation_phase","Entered...",UVM_HIGH)
    uvm_top.print_topology();
    `uvm_info("start_of_simulation_phase","Exiting...",UVM_HIGH)
  endfunction


endclass
