// tb_uart.v - self-checking testbench for uart_tx + uart_rx
//  1. Loopback: TX -> RX for corner-case and random bytes
//  2. Bit-timing check on the TX line (start bit width)
//  3. Framing error: a hand-driven frame with a 0 stop bit
//  4. Glitch rejection: a short low pulse must not start a frame
`timescale 1ns/1ps

module tb_uart;
    localparam integer CPB = 16;        // clocks per bit (small for fast sim)
    localparam integer N_RANDOM = 200;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    // ---- loopback pair ----
    reg        tx_start = 0;
    reg  [7:0] tx_data  = 0;
    wire       tx_line, tx_busy, tx_done;
    wire [7:0] rx_data;
    wire       rx_valid, rx_ferr;

    uart_tx #(.CLKS_PER_BIT(CPB)) u_tx (
        .clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
        .tx(tx_line), .busy(tx_busy), .done(tx_done)
    );
    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(tx_line),
        .data(rx_data), .valid(rx_valid), .frame_err(rx_ferr)
    );

    // ---- second receiver driven directly by the testbench ----
    reg        raw_line = 1;
    wire [7:0] raw_data;
    wire       raw_valid, raw_ferr;
    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx_raw (
        .clk(clk), .rst_n(rst_n), .rx(raw_line),
        .data(raw_data), .valid(raw_valid), .frame_err(raw_ferr)
    );

    integer errors = 0, seed = 1234, i, sent = 0;
    integer raw_valid_cnt = 0, raw_ferr_cnt = 0, lb_ferr_cnt = 0;
    integer t_fall, t_rise;

    always @(posedge clk) begin
        if (raw_valid) raw_valid_cnt = raw_valid_cnt + 1;
        if (raw_ferr)  raw_ferr_cnt  = raw_ferr_cnt + 1;
        if (rx_ferr)   lb_ferr_cnt   = lb_ferr_cnt + 1;
    end

    task send_and_check(input [7:0] b);
        begin
            @(negedge clk);
            while (tx_busy) @(negedge clk);
            tx_data = b; tx_start = 1;
            @(negedge clk) tx_start = 0;
            @(posedge rx_valid);
            #1;
            if (rx_data !== b) begin
                errors = errors + 1;
                $display("  ERROR: sent %h, received %h", b, rx_data);
            end
            sent = sent + 1;
        end
    endtask

    // Drive one 8N1 frame on raw_line with a chosen stop-bit value
    task send_raw(input [7:0] b, input stop_bit);
        integer k;
        begin
            raw_line = 0;           repeat (CPB) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                raw_line = b[k];    repeat (CPB) @(posedge clk);
            end
            raw_line = stop_bit;    repeat (CPB) @(posedge clk);
            raw_line = 1;           repeat (CPB * 2) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("build/tb_uart.vcd");
        $dumpvars(0, tb_uart);

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // 1. loopback
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'h01);
        send_and_check(8'h80);
        for (i = 0; i < N_RANDOM; i = i + 1)
            send_and_check($random(seed));
        if (lb_ferr_cnt != 0) begin
            errors = errors + 1;
            $display("  ERROR: %0d unexpected framing errors in loopback", lb_ferr_cnt);
        end

        // 2. start-bit width on the TX line
        @(negedge clk); while (tx_busy) @(negedge clk);
        tx_data = 8'hFE; tx_start = 1;      // LSB = 0, so start + bit0 are both low
        @(negedge tx_line) t_fall = $time;  // falls on the next clock edge
        @(negedge clk) tx_start = 0;
        @(posedge tx_line) t_rise = $time;
        if ((t_rise - t_fall) != 2 * CPB * 10) begin
            errors = errors + 1;
            $display("  ERROR: start+bit0 low time %0d ns, expected %0d ns",
                     t_rise - t_fall, 2 * CPB * 10);
        end
        @(posedge rx_valid);

        // 3. framing error
        send_raw(8'h3C, 1'b1);              // good frame
        send_raw(8'hC3, 1'b0);              // bad stop bit
        if (raw_valid_cnt != 1 || raw_ferr_cnt != 1) begin
            errors = errors + 1;
            $display("  ERROR: framing test valid=%0d ferr=%0d (expected 1/1)",
                     raw_valid_cnt, raw_ferr_cnt);
        end
        if (raw_data !== 8'h3C) begin
            errors = errors + 1;
            $display("  ERROR: raw receiver data %h, expected 3C", raw_data);
        end

        // 4. glitch shorter than half a bit must be ignored
        raw_line = 0; repeat (CPB / 4) @(posedge clk);
        raw_line = 1; repeat (CPB * 12) @(posedge clk);
        if (raw_valid_cnt != 1 || raw_ferr_cnt != 1) begin
            errors = errors + 1;
            $display("  ERROR: glitch was treated as a frame");
        end

        $display("tb_uart: %0d bytes looped back, %0d errors", sent, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("TIMEOUT");
        $display("TEST FAILED");
        $finish;
    end
endmodule
