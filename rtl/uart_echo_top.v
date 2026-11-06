// uart_echo_top.v
// Integration top: UART RX -> FIFO -> UART TX.
// Every byte received is echoed back. The FIFO absorbs bursts while the
// transmitter is busy. Drop this on an FPGA, open a serial terminal, and
// whatever you type comes back.
`timescale 1ns/1ps
`default_nettype none
/* verilator lint_off PINCONNECTEMPTY */  // unused status outputs left open on purpose

module uart_echo_top #(
    parameter integer CLKS_PER_BIT = 868,   // 100 MHz / 115200 baud
    parameter integer FIFO_DEPTH   = 16
) (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rxd,
    output wire uart_txd,
    output wire frame_err,
    output reg  overflow     // sticky: a byte arrived while the FIFO was full
);
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rxd),
        .data(rx_data), .valid(rx_valid), .frame_err(frame_err)
    );

    wire [7:0] fifo_data;
    wire       fifo_empty, fifo_full;
    wire       fifo_rd;

    sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(rx_valid), .wr_data(rx_data),
        .rd_en(fifo_rd),  .rd_data(fifo_data),
        .full(fifo_full), .empty(fifo_empty), .count()
    );

    // Hand a byte to the transmitter whenever it is idle and data is waiting.
    // tx_start is registered, so `busy` is high before we could issue again.
    reg       tx_start;
    reg [7:0] tx_byte;
    wire      tx_busy;

    assign fifo_rd = !tx_busy && !tx_start && !fifo_empty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start <= 1'b0;
            tx_byte  <= 8'd0;
        end else begin
            tx_start <= 1'b0;
            if (fifo_rd) begin
                tx_start <= 1'b1;
                tx_byte  <= fifo_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                      overflow <= 1'b0;
        else if (rx_valid && fifo_full)  overflow <= 1'b1;
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_byte),
        .tx(uart_txd), .busy(tx_busy), .done()
    );
endmodule

`default_nettype wire
