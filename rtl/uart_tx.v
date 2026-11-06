// uart_tx.v
// UART transmitter, 8N1 (8 data bits, no parity, 1 stop bit), LSB first.
// CLKS_PER_BIT = f_clk / baud  (e.g. 100 MHz / 115200 = 868)
`timescale 1ns/1ps
`default_nettype none

module uart_tx #(
    parameter integer CLKS_PER_BIT = 868
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,     // pulse to send `data` (ignored while busy)
    input  wire [7:0] data,
    output reg        tx,        // serial line, idles high
    output reg        busy,
    output reg        done       // one-cycle pulse when the stop bit ends
);
    localparam integer CW = $clog2(CLKS_PER_BIT + 1);
    localparam integer LAST_I = CLKS_PER_BIT - 1;
    localparam [CW-1:0] LAST = LAST_I[CW-1:0];
    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]    state;
    reg [CW-1:0] clk_cnt;
    reg [2:0]    bit_idx;
    reg [7:0]    shreg;

    wire bit_end = (clk_cnt == LAST);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx      <= 1'b1;
            busy    <= 1'b0;
            done    <= 1'b0;
            clk_cnt <= {CW{1'b0}};
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    clk_cnt <= {CW{1'b0}};
                    bit_idx <= 3'd0;
                    if (start) begin
                        shreg <= data;
                        busy  <= 1'b1;
                        tx    <= 1'b0;              // start bit
                        state <= START;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                START: begin
                    if (bit_end) begin
                        clk_cnt <= {CW{1'b0}};
                        tx      <= shreg[0];        // first data bit (LSB)
                        shreg   <= shreg >> 1;
                        state   <= DATA;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                DATA: begin
                    if (bit_end) begin
                        clk_cnt <= {CW{1'b0}};
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;          // stop bit
                            state <= STOP;
                        end else begin
                            tx      <= shreg[0];
                            shreg   <= shreg >> 1;
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                STOP: begin
                    if (bit_end) begin
                        clk_cnt <= {CW{1'b0}};
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        state   <= IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
