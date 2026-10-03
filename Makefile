IVERILOG ?= iverilog
VVP      ?= vvp
YOSYS    ?= yosys
GTKWAVE  ?= gtkwave

SRC = src/ecc_secded.v src/ddr_controller.v tb/ddr3_model.v tb/tb_ddr_controller.v

.PHONY: all sim synth wave clean

all: sim synth

sim: ddr_sim
	$(VVP) ddr_sim

ddr_sim: $(SRC)
	$(IVERILOG) -g2012 -o $@ $(SRC)

synth:
	cd scripts && $(YOSYS) -s ddr_controller.ys

wave: sim
	$(GTKWAVE) ddr_controller.vcd

clean:
	rm -f ddr_sim ddr_controller.vcd scripts/ddr_controller_synth.v scripts/*.log
