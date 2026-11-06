# Simulation flow: Icarus Verilog (iverilog + vvp), waveforms in GTKWave.
#
#   make            run every testbench
#   make <name>       run one testbench (any name listed in TESTS)
#   make wave-<name>  open that testbench's waveform in GTKWave
#   make clean

IVERILOG := iverilog -g2012 -Wall -Wno-timescale
VVP      := vvp -n
BUILD    := build

TESTS := debouncer sync_fifo

RTL_debouncer     := rtl/debouncer.v
RTL_sync_fifo     := rtl/sync_fifo.v

.PHONY: all test clean $(TESTS)

all: test

test: $(TESTS)
	@echo ""
	@echo "All $(words $(TESTS)) testbenches passed."

$(BUILD):
	@mkdir -p $(BUILD)

$(TESTS): %: | $(BUILD)
	@echo "=== $@ ==="
	@$(IVERILOG) -o $(BUILD)/tb_$@.vvp tb/tb_$@.v $(RTL_$@)
	@$(VVP) $(BUILD)/tb_$@.vvp | grep -v "VCD info" | tee $(BUILD)/tb_$@.log
	@grep -q "TEST PASSED" $(BUILD)/tb_$@.log

wave-%:
	gtkwave $(BUILD)/tb_$*.vcd &

clean:
	rm -rf $(BUILD)
