VSIM = vsim
VLOG = vlog
VLIB = vlib
VMAP = vmap

WORK = work
TOP  = tb_rv32i

RTL_F  = rtl.f
TB_SRC = ../TB/$(TOP).sv

VOPT_ARGS = -voptargs="+acc"

all: clean run

run: compile simulate

$(WORK):
	$(VLIB) $(WORK)
	$(VMAP) $(WORK) $(WORK)

compile: $(WORK)
	$(VLOG) -sv -f $(RTL_F) $(TB_SRC)

simulate:
	$(VSIM) -c $(TOP) $(VOPT_ARGS) -do "run -all; quit"

gui:
	$(VSIM) $(TOP) $(VOPT_ARGS)

wave:
	$(VSIM) $(TOP) $(VOPT_ARGS) -do "log -r /*; add wave -r /*; run -all"

clean:
	rm -rf $(WORK) transcript vsim.wlf *.log *.vcd wave.vcd