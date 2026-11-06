# Simulation flow: Icarus Verilog (iverilog + vvp), waveforms in GTKWave.
#
#   make            run every testbench
#   make <name>       run one testbench (any name listed in TESTS)
#   make wave-<name>  open that testbench's waveform in GTKWave
#   make clean

IVERILOG := iverilog -g2012 -Wall -Wno-timescale
VVP      := vvp -n
BUILD    := build

TESTS := debouncer sync_fifo uart spi_master traffic_light uart_echo_top

RTL_debouncer     := rtl/debouncer.v
RTL_sync_fifo     := rtl/sync_fifo.v
RTL_uart          := rtl/uart_tx.v rtl/uart_rx.v
RTL_spi_master    := rtl/spi_master.v
RTL_traffic_light := rtl/traffic_light.v
RTL_uart_echo_top := rtl/uart_tx.v rtl/uart_rx.v rtl/sync_fifo.v rtl/uart_echo_top.v

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
