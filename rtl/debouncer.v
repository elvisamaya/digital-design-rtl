// debouncer.v
// Push-button debouncer with a 2-flop synchronizer.
// The output only changes after the synchronized input has held a new
// value for STABLE_CYCLES consecutive clocks. `rise` pulses for one cycle
// on each debounced press (0 -> 1 transition).
`timescale 1ns/1ps
`default_nettype none

module debouncer #(
    parameter integer STABLE_CYCLES = 1_000_000  // ~10 ms at 100 MHz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,     // raw, asynchronous, bouncy input
    output reg  btn_out,    // clean, debounced level
    output reg  rise        // one-cycle pulse on debounced press
);
    localparam integer CW = $clog2(STABLE_CYCLES + 1);

    localparam integer LAST_I = STABLE_CYCLES - 1;
    localparam [CW-1:0] LAST = LAST_I[CW-1:0];

    // Two-flop synchronizer: protects against metastability on the async input
    reg sync0, sync1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= 1'b0;
            sync1 <= 1'b0;
        end else begin
            sync0 <= btn_in;
            sync1 <= sync0;
        end
    end

    reg [CW-1:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= {CW{1'b0}};
            btn_out <= 1'b0;
            rise    <= 1'b0;
        end else begin
            rise <= 1'b0;
            if (sync1 == btn_out) begin
                cnt <= {CW{1'b0}};                  // no change pending
            end else if (cnt == LAST) begin
                btn_out <= sync1;                   // held long enough: accept
                rise    <= sync1;
                cnt     <= {CW{1'b0}};
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
