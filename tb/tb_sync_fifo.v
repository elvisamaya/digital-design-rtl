// tb_sync_fifo.v - randomized, self-checking testbench for sync_fifo.
// A behavioral queue (scoreboard) predicts what the FIFO should do every
// cycle; flags, count, and head data are compared against it.
`timescale 1ns/1ps

module tb_sync_fifo;
    localparam integer WIDTH  = 8;
    localparam integer DEPTH  = 8;
    localparam integer CYCLES = 5000;

    reg              clk = 0, rst_n = 0;
    reg              wr_en = 0, rd_en = 0;
    reg  [WIDTH-1:0] wr_data = 0;
    wire [WIDTH-1:0] rd_data;
    wire             full, empty;
    wire [$clog2(DEPTH):0] count;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data),
        .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;

    // Scoreboard model
    reg [WIDTH-1:0] model [0:65535];
    integer head = 0, tail = 0, mcount = 0;
    integer errors = 0, seed = 42, cyc;
    integer n_wr = 0, n_rd = 0, n_full = 0, n_empty = 0;
    integer wr_bias, prev_count;

    initial begin
        $dumpfile("build/tb_sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);

        repeat (3) @(posedge clk);
        @(negedge clk) rst_n = 1;

        for (cyc = 0; cyc < CYCLES; cyc = cyc + 1) begin
            @(negedge clk);

            // ---- check outputs against the model ----
            if (count !== mcount) begin
                errors = errors + 1;
                $display("  ERROR @%0t: count=%0d expected %0d", $time, count, mcount);
            end
            if (empty !== (mcount == 0)) begin
                errors = errors + 1;
                $display("  ERROR @%0t: empty=%b with model count %0d", $time, empty, mcount);
            end
            if (full !== (mcount == DEPTH)) begin
                errors = errors + 1;
                $display("  ERROR @%0t: full=%b with model count %0d", $time, full, mcount);
            end
            if (mcount > 0 && rd_data !== model[head]) begin
                errors = errors + 1;
                $display("  ERROR @%0t: rd_data=%h expected %h", $time, rd_data, model[head]);
            end
            if (full)  n_full  = n_full + 1;
            if (empty) n_empty = n_empty + 1;

            // ---- drive random stimulus; bias phases toward filling / draining ----
            wr_bias = ((cyc / 500) % 2) ? 75 : 25;
            wr_en   = ({$random(seed)} % 100) < wr_bias;
            rd_en   = ({$random(seed)} % 100) < (100 - wr_bias);
            wr_data = $random(seed);

            // ---- update the model with what the next edge will do ----
            // (writes are ignored when full, even if a read happens the same cycle)
            prev_count = mcount;
            if (rd_en && prev_count > 0) begin
                head = head + 1; mcount = mcount - 1; n_rd = n_rd + 1;
            end
            if (wr_en && prev_count < DEPTH) begin
                model[tail] = wr_data; tail = tail + 1; mcount = mcount + 1; n_wr = n_wr + 1;
            end
        end

        $display("tb_sync_fifo: %0d writes, %0d reads, full %0d cycles, empty %0d cycles, %0d errors",
                 n_wr, n_rd, n_full, n_empty, errors);
        if (n_full == 0 || n_empty == 0) begin
            errors = errors + 1;
            $display("  ERROR: stimulus never reached full and empty (coverage hole)");
        end
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end
endmodule
