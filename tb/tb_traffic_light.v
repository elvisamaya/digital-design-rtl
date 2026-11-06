// tb_traffic_light.v - self-checking testbench for traffic_light
// Checks safety and liveness properties every cycle, assertion-style:
//   - each light is exactly one of red / yellow / green
//   - the two roads are never both non-red (no conflicting traffic)
//   - WALK only while both roads are red
//   - green is always followed by yellow, never straight to red
//   - green and yellow last exactly GREEN_T / YELLOW_T cycles
//   - every pedestrian request is served
`timescale 1ns/1ps

module tb_traffic_light;
    localparam integer GREEN_T = 12, YELLOW_T = 3, ALLRED_T = 2, WALK_T = 6;
    localparam integer CYCLES = 20000;
    localparam [2:0] RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;

    reg clk = 0, rst_n = 0, ped_req = 0;
    wire [2:0] ns, ew;
    wire walk;

    traffic_light #(.GREEN_T(GREEN_T), .YELLOW_T(YELLOW_T),
                    .ALLRED_T(ALLRED_T), .WALK_T(WALK_T)) dut (
        .clk(clk), .rst_n(rst_n), .ped_req(ped_req),
        .ns(ns), .ew(ew), .walk(walk)
    );

    always #5 clk = ~clk;

    integer errors = 0, seed = 5, cyc;
    integer ns_run = 0, ew_run = 0;     // cycles spent in the current colour
    integer ns_run_last = 0, ew_run_last = 0;
    integer walks = 0, reqs = 0, waiting = 0, max_wait = 0;
    reg [2:0] ns_prev = RED, ew_prev = RED;
    reg walk_prev = 0;

    task fail(input [8*64-1:0] msg);
        begin
            errors = errors + 1;
            if (errors < 20) $display("  ERROR @%0t: %0s (ns=%b ew=%b walk=%b)", $time, msg, ns, ew, walk);
        end
    endtask

    // Check one road: legal colour transitions and exact durations
    task check_road(input [2:0] cur, input [2:0] prev, input integer run, input check_dur);
        begin
            if (cur != RED && cur != YELLOW && cur != GREEN) fail("light not one-hot");
            if (prev == GREEN && cur == RED)                  fail("green went straight to red");
            if (prev == RED   && cur == YELLOW)               fail("red went to yellow");
            if (prev == YELLOW && cur == GREEN)               fail("yellow went to green");
            if (check_dur && prev == GREEN  && cur != GREEN && run != GREEN_T)  fail("wrong green duration");
            if (check_dur && prev == YELLOW && cur != YELLOW && run != YELLOW_T) fail("wrong yellow duration");
        end
    endtask

    initial begin
        $dumpfile("build/tb_traffic_light.vcd");
        $dumpvars(0, tb_traffic_light);

        repeat (3) @(posedge clk);
        @(negedge clk) rst_n = 1;

        for (cyc = 0; cyc < CYCLES; cyc = cyc + 1) begin
            @(negedge clk);

            // random pedestrian presses (~1 per 150 cycles)
            ped_req = ({$random(seed)} % 150) == 0;
            if (ped_req && waiting == 0) begin reqs = reqs + 1; waiting = 1; end
            else if (waiting > 0) waiting = waiting + 1;

            // safety
            if (ns != RED && ew != RED)        fail("both roads open");
            if (walk && (ns != RED || ew != RED)) fail("walk while traffic moving");

            // sequencing + durations
            ns_run = (ns == ns_prev) ? ns_run + 1 : 1;
            ew_run = (ew == ew_prev) ? ew_run + 1 : 1;
            // (the first green after reset is skipped: it starts mid-phase)
            check_road(ns, ns_prev, ns_run_last, cyc > GREEN_T);
            check_road(ew, ew_prev, ew_run_last, cyc > GREEN_T);

            // liveness: requests get served
            if (walk && !walk_prev) begin
                walks = walks + 1;
                if (waiting > max_wait) max_wait = waiting;
                waiting = 0;
            end

            ns_run_last = ns_run;
            ew_run_last = ew_run;
            ns_prev = ns; ew_prev = ew; walk_prev = walk;
        end

        $display("tb_traffic_light: %0d cycles, %0d walk phases, longest wait %0d cycles, %0d errors",
                 CYCLES, walks, max_wait, errors);
        if (walks == 0) fail("pedestrian walk phase never happened");
        if (max_wait > 2 * (GREEN_T + YELLOW_T + ALLRED_T) + WALK_T + 4) fail("pedestrian waited too long");
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule
