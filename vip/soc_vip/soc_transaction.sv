class soc_transaction extends uvm_sequence_item;

    rand    [127:0] data_128;
    rand    [255:0] data_256;
    rand    [511:0] data_512;

    `uvm_object_utils_begin (soc_transaction)
        `uvm_field_int(data_128,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(data_256,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(data_512,        UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "soc_transaction");
        super.new(name);
    endfunction

endclass