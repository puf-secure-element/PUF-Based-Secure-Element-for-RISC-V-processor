+incdir+${ECC_VIP_VERIF_PATH}/tb/uvm
+incdir+${ECC_VIP_VERIF_PATH}/vip/ecc_vip
+incdir+${ECC_VIP_VERIF_PATH}/sequences
+incdir+${ECC_VIP_VERIF_PATH}/testcases

-f ${ECC_VIP_ROOT}/ecc_vip.f

${ECC_VIP_VERIF_PATH}/tb/uvm/ecc_env_pkg.sv
${ECC_VIP_VERIF_PATH}/sequences/seq_pkg.sv
${ECC_VIP_VERIF_PATH}/testcases/test_pkg.sv
${ECC_VIP_VERIF_PATH}/tb/uvm/testbench.sv