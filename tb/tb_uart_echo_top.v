// tb_uart_echo_top.v - integration test: RX -> FIFO -> TX echo
// A testbench-side UART transmitter sends a string back-to-back into the
// DUT; a testbench-side receiver collects what the DUT echoes.
`timescale 1ns/1ps

module tb_uart_echo_top;
    localparam integer CPB = 16;
    localparam integer LEN = 24;
    localparam [8*LEN-1:0] MSG = "Hello from Verilog RTL!\n";

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    // host -> DUT
    reg        h_start = 0;
    reg  [7:0] h_data  = 0;
    wire       h_txd, h_busy, h_done;
    uart_tx #(.CLKS_PER_BIT(CPB)) host_tx (
        .clk(clk), .rst_n(rst_n), .start(h_start), .data(h_data),
        .tx(h_txd), .busy(h_busy), .done(h_done)
    );

    // DUT
    wire dut_txd, dut_ferr, dut_ovf;
    uart_echo_top #(.CLKS_PER_BIT(CPB), .FIFO_DEPTH(8)) dut (
        .clk(clk), .rst_n(rst_n), .uart_rxd(h_txd), .uart_txd(dut_txd), .frame_err(dut_ferr), .overflow(dut_ovf)
    );

    // DUT -> host
    wire [7:0] h_rx_data;
    wire       h_rx_valid, h_rx_ferr;
    uart_rx #(.CLKS_PER_BIT(CPB)) host_rx (
        .clk(clk), .rst_n(rst_n), .rx(dut_txd),
        .data(h_rx_data), .valid(h_rx_valid), .frame_err(h_rx_ferr)
    );

    reg [7:0] got [0:LEN-1];
    integer n_got = 0, errors = 0, i;

    always @(posedge clk) begin
        if (h_rx_valid) begin
            if (n_got < LEN) got[n_got] = h_rx_data;
            n_got = n_got + 1;
        end
        if (h_rx_ferr || dut_ferr) begin
            errors = errors + 1;
            $display("  ERROR @%0t: framing error", $time);
        end
    end

    initial begin
        $dumpfile("build/tb_uart_echo_top.vcd");
        $dumpvars(0, tb_uart_echo_top);

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // send the whole message back-to-back
        for (i = 0; i < LEN; i = i + 1) begin
            @(negedge clk);
            while (h_busy) @(negedge clk);
            h_data  = MSG[8*(LEN-1-i) +: 8];
            h_start = 1;
            @(negedge clk) h_start = 0;
        end

        // wait for the echo to drain
        wait (n_got == LEN);
        repeat (CPB * 20) @(posedge clk);

        if (dut_ovf) begin
            errors = errors + 1;
            $display("  ERROR: FIFO overflow flagged");
        end
        if (n_got != LEN) begin
            errors = errors + 1;
            $display("  ERROR: echoed %0d bytes, expected %0d", n_got, LEN);
        end
        $write("  echoed: \"");
        for (i = 0; i < LEN; i = i + 1) begin
            if (got[i] !== MSG[8*(LEN-1-i) +: 8]) begin
                errors = errors + 1;
                $display("\n  ERROR: byte %0d = %h, expected %h", i, got[i], MSG[8*(LEN-1-i) +: 8]);
            end
            if (got[i] >= 8'h20 && got[i] < 8'h7f) $write("%c", got[i]);
        end
        $display("\"");

        $display("tb_uart_echo_top: %0d bytes echoed, %0d errors", n_got, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #20_000_000;
        $display("TIMEOUT");
        $display("TEST FAILED");
        $finish;
    end
endmodule
