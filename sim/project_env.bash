#!/bin/bash -f

export UVM_HOME=/opt/mentor_graphic/mentor_graphic/questasim/install/questasim/verilog_src/uvm-1.2

export PROJ_ROOT=./..

export RTL_ROOT=${PROJ_ROOT}/rtl

export VIP_ROOT=${PROJ_ROOT}/vip
export ECC_VIP_ROOT=${VIP_ROOT}/ecc_vip
export SOC_VIP_ROOT=${VIP_ROOT}/soc_vip

export ECC_VIP_VERIF_PATH=${PROJ_ROOT}

export TB_ROOT=${PROJ_ROOT}/tb/uvm