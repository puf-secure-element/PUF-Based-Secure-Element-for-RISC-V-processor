class ecc_agent extends uvm_agent;
  `uvm_component_utils(ecc_agent)

  ecc_monitor    mon;
  ecc_driver     drv;
  ecc_sequencer  seq;

  virtual   ecc_interface   ecc_vif;

  function new(string name = "ecc_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(virtual ecc_interface)::get(this, "", "ecc_vif", ecc_vif))
      `uvm_fatal(get_type_name(), $sformatf("FAILED to get ECC_INTERFACE from uvm_config_db"))

    if(is_active == UVM_ACTIVE) begin
      //`uvm_info(get_type_name(), $sformatf("Active agent is configured"), UVM_LOW)

      drv   = ecc_driver::type_id::create("driver", this);
      mon   = ecc_monitor::type_id::create("monitor", this);
      seq   = ecc_sequencer::type_id::create("sequencer", this);

      uvm_config_db#(virtual ecc_interface)::set(this, "driver", "ecc_vif", ecc_vif);
      uvm_config_db#(virtual ecc_interface)::set(this, "monitor", "ecc_vif", ecc_vif);
    end
    else begin
      //`uvm_info(get_type_name(), $sformatf("Passive agent is configured"), UVM_LOW)

      mon   = ecc_monitor::type_id::create("monitor", this);

      uvm_config_db#(virtual ecc_interface)::set(this, "monitor", "ecc_vif", ecc_vif);
    end

  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seq.seq_item_export);
    end
  endfunction

endclass