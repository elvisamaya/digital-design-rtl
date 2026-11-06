// tb_debouncer.v - self-checking testbench for debouncer
`timescale 1ns/1ps

module tb_debouncer;
    localparam integer STABLE = 50;

    reg  clk = 0, rst_n = 0, btn = 0;
    wire btn_out, rise;

    debouncer #(.STABLE_CYCLES(STABLE)) dut (
        .clk(clk), .rst_n(rst_n), .btn_in(btn), .btn_out(btn_out), .rise(rise)
    );

    always #5 clk = ~clk;   // 100 MHz

    integer errors = 0, rises = 0, seed = 7, i;

    always @(posedge clk) if (rise) rises = rises + 1;

    task check(input cond, input [8*64-1:0] msg);
        if (!cond) begin
            errors = errors + 1;
            $display("  ERROR @%0t: %0s", $time, msg);
        end
    endtask

    // Bounce the input several times (each segment shorter than STABLE),
    // then settle at `level`.
    task bounce_to(input level);
        integer n, len;
        begin
            n = 3 + ({$random(seed)} % 8);
            repeat (n) begin
                btn = ~btn;
                len = 1 + ({$random(seed)} % (STABLE / 3));
                repeat (len) @(posedge clk);
            end
            btn = level;
        end
    endtask

    initial begin
        $dumpfile("build/tb_debouncer.vcd");
        $dumpvars(0, tb_debouncer);

        repeat (5) @(posedge clk);
        rst_n = 1;

        for (i = 0; i < 10; i = i + 1) begin
            // press
            bounce_to(1'b1);
            check(btn_out == 1'b0, "output changed during press bounce");
            repeat (STABLE + 5) @(posedge clk);
            check(btn_out == 1'b1, "press not accepted after stable time");
            // release
            bounce_to(1'b0);
            check(btn_out == 1'b1, "output changed during release bounce");
            repeat (STABLE + 5) @(posedge clk);
            check(btn_out == 1'b0, "release not accepted after stable time");
        end
        check(rises == 10, "expected exactly 10 rise pulses");

        // A short glitch must be rejected entirely
        btn = 1'b1; repeat (STABLE / 2) @(posedge clk);
        btn = 1'b0; repeat (STABLE * 2) @(posedge clk);
        check(btn_out == 1'b0, "glitch passed through");
        check(rises == 10, "glitch produced a rise pulse");

        $display("tb_debouncer: %0d presses, %0d rise pulses, %0d errors", i, rises, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end
endmodule
