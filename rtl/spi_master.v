// spi_master.v
// SPI master, mode 0 (CPOL = 0, CPHA = 0), MSB first, one byte per transfer.
// MOSI changes on SCLK falling edges; MISO is sampled on SCLK rising edges.
// SCLK frequency = f_clk / (2 * CLK_DIV).
`timescale 1ns/1ps
`default_nettype none

module spi_master #(
    parameter integer CLK_DIV = 4          // system clocks per SCLK half-period
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,      // pulse to begin a transfer (ignored while busy)
    input  wire [7:0] tx_byte,
    output reg  [7:0] rx_byte,
    output reg        busy,
    output reg        done,       // one-cycle pulse when transfer completes
    // SPI bus
    output reg        sclk,
    output reg        mosi,
    input  wire       miso,
    output reg        cs_n
);
    localparam integer CW = $clog2(CLK_DIV + 1);
    localparam integer LAST_I = CLK_DIV - 1;
    localparam [CW-1:0] LAST = LAST_I[CW-1:0];
    localparam [1:0] IDLE = 2'd0, XFER = 2'd1, FINISH = 2'd2;

    reg [1:0]    state;
    reg [CW-1:0] div_cnt;
    reg [2:0]    bit_cnt;
    reg [7:0]    tx_sh, rx_sh;

    wire half_end = (div_cnt == LAST);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            div_cnt <= {CW{1'b0}};
            bit_cnt <= 3'd0;
            tx_sh   <= 8'd0;
            rx_sh   <= 8'd0;
            rx_byte <= 8'd0;
            busy    <= 1'b0;
            done    <= 1'b0;
            sclk    <= 1'b0;
            mosi    <= 1'b0;
            cs_n    <= 1'b1;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    sclk    <= 1'b0;
                    div_cnt <= {CW{1'b0}};
                    bit_cnt <= 3'd0;
                    if (start) begin
                        tx_sh <= tx_byte;
                        mosi  <= tx_byte[7];        // MSB valid before 1st rising edge
                        cs_n  <= 1'b0;
                        busy  <= 1'b1;
                        state <= XFER;
                    end
                end

                XFER: begin
                    if (half_end) begin
                        div_cnt <= {CW{1'b0}};
                        if (!sclk) begin            // rising edge: sample MISO
                            sclk  <= 1'b1;
                            rx_sh <= {rx_sh[6:0], miso};
                        end else begin              // falling edge: shift MOSI
                            sclk <= 1'b0;
                            if (bit_cnt == 3'd7) begin
                                state <= FINISH;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                                tx_sh   <= tx_sh << 1;
                                mosi    <= tx_sh[6];
                            end
                        end
                    end else
                        div_cnt <= div_cnt + 1'b1;
                end

                FINISH: begin                       // hold CS for half a period, then release
                    if (half_end) begin
                        div_cnt <= {CW{1'b0}};
                        cs_n    <= 1'b1;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        rx_byte <= rx_sh;
                        state   <= IDLE;
                    end else
                        div_cnt <= div_cnt + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
