class ecc_transaction extends uvm_sequence_item;

    typedef enum bit {
        ENROLLMENT = 1'b0,
        RECONSTRUCTION = 1'b1
    } ecc_mode;

    ecc_mode mode;

    rand    bit [511:0] response;
    rand    bit [95:0]  helper;

    `uvm_object_utils_begin (ecc_transaction)
        `uvm_field_enum(ecc_mode, mode, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(response,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(helper,          UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "ecc_transaction");
        super.new(name);
    endfunction

endclass