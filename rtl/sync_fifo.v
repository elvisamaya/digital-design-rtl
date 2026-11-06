// sync_fifo.v
// Synchronous (single-clock) FIFO, first-word fall-through.
// rd_data always shows the oldest entry while !empty; asserting rd_en pops it.
// Pointers carry one extra MSB so full and empty can be told apart.
// Writes when full and reads when empty are ignored.
`timescale 1ns/1ps
`default_nettype none

module sync_fifo #(
    parameter integer WIDTH = 8,
    parameter integer DEPTH = 16          // must be a power of two
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     wr_en,
    input  wire [WIDTH-1:0]         wr_data,
    input  wire                     rd_en,
    output wire [WIDTH-1:0]         rd_data,
    output wire                     full,
    output wire                     empty,
    output wire [$clog2(DEPTH):0]   count
);
    localparam integer AW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0]      wptr, rptr;

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk) begin
        if (do_wr)
            mem[wptr[AW-1:0]] <= wr_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= {(AW+1){1'b0}};
            rptr <= {(AW+1){1'b0}};
        end else begin
            if (do_wr) wptr <= wptr + 1'b1;
            if (do_rd) rptr <= rptr + 1'b1;
        end
    end

    assign rd_data = mem[rptr[AW-1:0]];
    assign empty   = (wptr == rptr);
    assign full    = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
    assign count   = wptr - rptr;
endmodule

`default_nettype wire
