class ecc_test_sequence extends uvm_sequence #(ecc_transaction);
    `uvm_object_utils(ecc_test_sequence)

    function new(string name = "ecc_test_sequence");
        super.new(name);
    endfunction

    virtual task body();

        bit [511:0] enroll_resp;
        bit [511:0] corrupted_resp;
        int         bit_idx;
        int         round;

        for (round = 0; round < 5; round++) begin

            `uvm_info("SEQ", $sformatf("\n\n===== ROUND %0d: ENROLLMENT =====\n", round), UVM_LOW)

            req = ecc_transaction::type_id::create("req");
            start_item(req);

            assert(req.randomize() with {
                mode == ecc_transaction::ENROLLMENT;
            });

            enroll_resp = req.response;

            finish_item(req);
            get_response(rsp);

            //`uvm_info("SEQ", $sformatf("Enrollment done. helper(internal)=%h", rsp.helper), UVM_LOW)

            repeat (10) begin
                req = ecc_transaction::type_id::create("req");
                start_item(req);

                req.mode = ecc_transaction::RECONSTRUCTION;

                corrupted_resp = enroll_resp;

                assert(std::randomize(bit_idx) with {
                    bit_idx inside {[0:511]};
                });

                corrupted_resp[bit_idx] = ~corrupted_resp[bit_idx];

                req.response = corrupted_resp;

                finish_item(req);
                get_response(rsp);

                `uvm_info("SEQ", $sformatf("Round %0d: injected 1-bit error at bit %0d", round, bit_idx), UVM_LOW)
            end

        end

    endtask

endclass