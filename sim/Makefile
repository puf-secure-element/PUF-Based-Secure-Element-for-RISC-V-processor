TB_NAME   ?=testbench  
TESTNAME  ?=uart_base_test
VERBOSITY ?=UVM_HIGH
RUNARG    ?=
SEED      ?=1
COV       ?=ON

#==============================
ifeq ($(COV),ON)
  CMP_COV_OPT   = -coveropt 3 +cover=bcestf 
  SIM1_COV_OPT  = -coverage -coveranalysis  
  SIM2_COV_OPT  = coverage save -codeAll -cvg -onexit $(TESTNAME)_$(SEED).ucdb;
endif

ifeq ($(strip $(SEED)),random)
  SEED = $(shell /bin/date +%s)
endif

##==============================================================
VLOG =  vlog ${CMP_COV_OPT} \
        -timescale "1us/1ns" \
        +define+UVM_NO_DPI \
        -mfcu \
        -suppress 2181 \
        +acc \
        +incdir+$(UVM_HOME)/src \
        $(UVM_HOME)/src/uvm.sv
		
VSIM =  vsim \
        -sv_seed ${SEED} ${SIM1_COV_OPT}\
        -voptargs=+acc \
        -assertdebug \
        -c ${TB_NAME}\
        -do "${SIM2_COV_OPT} log -r /*;run -all;" \
        -l $(TESTNAME)_$(SEED).log	
##==============================================================

all: build run
build: 	vlib
	$(VLOG)  -f compile.f \
  	+define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR 
		
run:
	$(VSIM) +UVM_TESTNAME=$(TESTNAME) \
          +UVM_VERBOSITY=$(VERBOSITY) \
	        ${RUNARG} 
	mv ${TESTNAME}_$(SEED).log ./log
	cp -rf vsim.wlf log/$(TESTNAME)_$(SEED).wlf
	ln -sf ./log/${TESTNAME}_$(SEED).log run.log

vlib:
	mkdir -p log
	vlib work
	vmap work work

wave:
	vsim -i -view vsim.wlf -do "add wave vsim:/$(TB_NAME)/*;" &

cov_gui:
	vsim -i -viewcov $(TESTNAME)_$(SEED).ucdb &

cov_merge:
	vcover merge IP_MERGE.ucdb *.ucdb

clean: 
	rm -rf work
	rm -rf log
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.trace
	rm -rf *.wlf
	rm -rf transcript
	rm -rf *.ucdb
	rm -rf vsim.dbg
	rm -rf tmp_report

help:
	@echo ""
	@echo "****************************************"
	@echo "** make build: compile the design and testbench"
	@echo "** make run  : run simulation"
	@echo "** make all  : compile and run simulation"
	@echo "** make wave : open waveform"
	@echo "** make clean: clean all compiled data"
	@echo "****************************************"
	@echo ""
