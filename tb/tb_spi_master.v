// tb_spi_master.v - self-checking testbench for spi_master
// A behavioral mode-0 SPI slave exchanges a byte with the master each
// transfer; both directions are checked, plus idle-state bus rules.
`timescale 1ns/1ps

module tb_spi_master;
    localparam integer CLK_DIV = 4;
    localparam integer N = 200;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg        start = 0;
    reg  [7:0] tx_byte = 0;
    wire [7:0] rx_byte;
    wire       busy, done, sclk, mosi, cs_n, miso;

    spi_master #(.CLK_DIV(CLK_DIV)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tx_byte(tx_byte),
        .rx_byte(rx_byte), .busy(busy), .done(done),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    // ---- behavioral SPI slave (mode 0) ----
    reg [7:0] slave_tx = 0;     // byte the slave will send
    reg [7:0] slave_sh = 0;
    reg [7:0] slave_rx = 0;
    integer   slave_edges = 0;

    assign miso = cs_n ? 1'bz : slave_sh[7];

    always @(negedge cs_n) begin
        slave_sh    = slave_tx;
        slave_edges = 0;
    end
    always @(posedge sclk) if (!cs_n) begin
        slave_rx    <= {slave_rx[6:0], mosi};
        slave_edges = slave_edges + 1;
    end
    always @(negedge sclk) if (!cs_n) slave_sh <= {slave_sh[6:0], 1'b0};

    // ---- bus rule: SCLK must idle low whenever CS is high ----
    integer errors = 0, seed = 99, i;
    always @(posedge clk) if (rst_n && cs_n && sclk) begin
        errors = errors + 1;
        $display("  ERROR @%0t: SCLK high while CS deasserted", $time);
    end

    task transfer(input [7:0] m_byte, input [7:0] s_byte);
        begin
            @(negedge clk);
            while (busy) @(negedge clk);
            slave_tx = s_byte;
            tx_byte  = m_byte;
            start    = 1;
            @(negedge clk) start = 0;
            @(posedge done);
            #1;
            if (rx_byte !== s_byte) begin
                errors = errors + 1;
                $display("  ERROR: master received %h, slave sent %h", rx_byte, s_byte);
            end
            if (slave_rx !== m_byte) begin
                errors = errors + 1;
                $display("  ERROR: slave received %h, master sent %h", slave_rx, m_byte);
            end
            if (slave_edges != 8) begin
                errors = errors + 1;
                $display("  ERROR: %0d SCLK rising edges, expected 8", slave_edges);
            end
            if (!cs_n) begin
                errors = errors + 1;
                $display("  ERROR: CS still asserted after done");
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        repeat (5) @(posedge clk);
        rst_n = 1;

        transfer(8'hA5, 8'h5A);
        transfer(8'h00, 8'hFF);
        transfer(8'hFF, 8'h00);
        transfer(8'h80, 8'h01);
        for (i = 0; i < N; i = i + 1)
            transfer($random(seed), $random(seed));

        $display("tb_spi_master: %0d transfers, %0d errors", N + 4, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #10_000_000;
        $display("TIMEOUT");
        $display("TEST FAILED");
        $finish;
    end
endmodule
