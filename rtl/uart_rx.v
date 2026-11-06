// uart_rx.v
// UART receiver, 8N1, LSB first. Samples each bit in its middle.
// A false start bit (line back high at mid-bit) is rejected.
// A low stop bit raises `frame_err` instead of `valid`.
`timescale 1ns/1ps
`default_nettype none

module uart_rx #(
    parameter integer CLKS_PER_BIT = 868
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,         // asynchronous serial input
    output reg  [7:0] data,
    output reg        valid,      // one-cycle pulse: `data` holds a new byte
    output reg        frame_err   // one-cycle pulse: stop bit was 0
);
    localparam integer CW = $clog2(CLKS_PER_BIT + 1);
    localparam integer LAST_I = CLKS_PER_BIT - 1;
    localparam [CW-1:0] LAST = LAST_I[CW-1:0];
    localparam integer HALF_I = (CLKS_PER_BIT - 1) / 2;
    localparam [CW-1:0] HALF = HALF_I[CW-1:0];
    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    // 2-flop synchronizer (line idles high)
    reg rx_s0, rx_s1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s0 <= 1'b1;
            rx_s1 <= 1'b1;
        end else begin
            rx_s0 <= rx;
            rx_s1 <= rx_s0;
        end
    end

    reg [1:0]    state;
    reg [CW-1:0] cnt;
    reg [2:0]    bit_idx;
    reg [7:0]    shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cnt       <= {CW{1'b0}};
            bit_idx   <= 3'd0;
            shreg     <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            valid     <= 1'b0;
            frame_err <= 1'b0;
            case (state)
                IDLE: begin
                    cnt     <= {CW{1'b0}};
                    bit_idx <= 3'd0;
                    if (!rx_s1) state <= START;     // falling edge = start bit
                end

                START: begin                        // wait half a bit -> mid start bit
                    if (cnt == HALF) begin
                        cnt   <= {CW{1'b0}};
                        state <= rx_s1 ? IDLE : DATA;   // glitch rejection
                    end else
                        cnt <= cnt + 1'b1;
                end

                DATA: begin                         // one full bit -> mid next bit
                    if (cnt == LAST) begin
                        cnt   <= {CW{1'b0}};
                        shreg <= {rx_s1, shreg[7:1]};   // LSB arrives first
                        if (bit_idx == 3'd7) state <= STOP;
                        else                 bit_idx <= bit_idx + 1'b1;
                    end else
                        cnt <= cnt + 1'b1;
                end

                STOP: begin
                    if (cnt == LAST) begin
                        cnt   <= {CW{1'b0}};
                        state <= IDLE;
                        if (rx_s1) begin
                            data  <= shreg;
                            valid <= 1'b1;
                        end else
                            frame_err <= 1'b1;
                    end else
                        cnt <= cnt + 1'b1;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
