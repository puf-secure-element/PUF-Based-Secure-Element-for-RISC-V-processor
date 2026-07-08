VSIM = vsim
VLOG = vlog
VLIB = vlib
VMAP = vmap

WORK = work
TOP  = tb_sub_bytes

RTL_F  = rtl.f
TB_SRC = ../tb/unit_tests/$(TOP).v
TB_MODELS = ../tb/golden_models/aes_sbox_golden.v

VOPT_ARGS = -voptargs="+acc"

all: clean run

run: compile simulate

$(WORK):
	$(VLIB) $(WORK)
	$(VMAP) $(WORK) $(WORK)

compile: $(WORK)
	$(VLOG) -sv -f $(RTL_F) $(TB_MODELS) $(TB_SRC)

simulate:
	$(VSIM) -c $(TOP) $(VOPT_ARGS) -do "run -all; quit"

gui:
	$(VSIM) $(TOP) $(VOPT_ARGS)

wave:
	$(VSIM) $(TOP) $(VOPT_ARGS) -do "log -r /*; add wave -r /*; run -all"

clean:
	rm -rf $(WORK) transcript vsim.wlf *.log *.vcd wave.vcd