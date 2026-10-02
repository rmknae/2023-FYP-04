
// =====================================================================
// uart_tx_tb.sv -- testbench for uart_tx.sv
//
// Tests the UART transmitter by sending the byte 0x48 ('H').
// The transmitted frame is checked for:
// start bit -> 8 data bits (LSB first) -> stop bit.
//
// A smaller clock-to-baud ratio is used during simulation so that the
// test completes quickly.
//
// Stimulus is driven on the NEGEDGE of clk, while the DUT updates on
// the POSEDGE. This keeps the testbench stimulus separate from the
// DUT's clocked logic.
// =====================================================================

`timescale 1ns / 1ps

module uart_tx_tb;

    logic       clk = 0;
    logic       rst_n;
    logic [7:0] data_in;
    logic       send;
    logic       tx;
    logic       busy;

    // Small value used only to make simulation faster.
    localparam int CLKS_PER_BIT = 10;

    // UART transmitter under test.
    uart_tx #(
        .CLK_FREQ_HZ(1000),
        .BAUD_RATE  (100)
    ) dut (
        .clk,
        .rst_n,
        .data_in,
        .send,
        .tx,
        .busy
    );

    // 10 ns clock period.
    always #5 clk = ~clk;

    // Stores the complete UART frame:
    // {stop, data[7:0], start}
    logic [9:0] captured;

    // ---------------------------------------------------------------
    // Generate reset and send the test byte.
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);

        rst_n   = 0;
        data_in = 8'h00;
        send    = 0;

        $display("==============================================");
        $display("       UART TX SIMULATION START               ");
        $display("==============================================");
        $display("Clock period    : 10 ns");
        $display("Clocks per bit  : %0d", CLKS_PER_BIT);
        $display("Test byte       : 0x48 ('H')");
        $display("----------------------------------------------");

        // Apply reset for three clock cycles.
        $display("[%0t ns] Applying reset...", $time);

        @(negedge clk);
        @(negedge clk);
        @(negedge clk);

        rst_n = 1;

        $display("[%0t ns] Reset released.", $time);
        $display("[%0t ns] TX idle state = %b", $time, tx);
        $display("----------------------------------------------");

        // Load the test byte and request a transmission.
        data_in = 8'h48;
        send    = 1;

        $display("[%0t ns] Sending byte: 0x%02h ('%c')",
                 $time, data_in, data_in);

        @(negedge clk);

        send = 0;

        $display("[%0t ns] Send pulse released.", $time);
        $display("[%0t ns] UART busy = %b", $time, busy);
        $display("----------------------------------------------");

        // Wait until the complete frame has been transmitted.
        wait (busy == 1'b0);

        $display("[%0t ns] UART transmission completed.", $time);
        $display("[%0t ns] UART busy = %b", $time, busy);
        $display("----------------------------------------------");

        repeat (5) @(negedge clk);

        $display("Simulation finished.");
        $display("==============================================");

        $finish;
    end

    // ---------------------------------------------------------------
    // Capture and decode the transmitted UART frame.
    // ---------------------------------------------------------------
    initial begin

        // Wait until the testbench requests a transmission.
        wait (send == 1'b1);

        $display("[%0t ns] Frame capture started.", $time);
        $display("----------------------------------------------");

        // Wait for the first clock after send is asserted.
        @(posedge clk);

        // Sample once during each UART bit period.
        for (int i = 0; i < 10; i++) begin

            repeat (CLKS_PER_BIT) @(posedge clk);

            captured[i] = tx;

            // Print the value of every transmitted bit.
            if (i == 0) begin
                $display(
                    "[%0t ns] Bit %0d: START bit = %b",
                    $time, i, tx
                );
            end
            else if (i <= 8) begin
                $display(
                    "[%0t ns] Bit %0d: DATA bit %0d = %b",
                    $time, i, i - 1, tx
                );
            end
            else begin
                $display(
                    "[%0t ns] Bit %0d: STOP bit = %b",
                    $time, i, tx
                );
            end
        end

        $display("----------------------------------------------");

        // Display the complete decoded frame.
        $display("Decoded UART frame:");
        $display("  Start bit : %b", captured[0]);
        $display("  Data bits : %b", captured[8:1]);
        $display("  Data hex  : 0x%02h", captured[8:1]);
        $display("  Stop bit  : %b", captured[9]);

        $display("----------------------------------------------");

        // Check the complete UART frame.
        if (captured[0] === 1'b0 &&
            captured[8:1] === 8'h48 &&
            captured[9] === 1'b1) begin

            $display("RESULT: PASS");
            $display("Start bit is correct.");
            $display("Data matches 0x48 ('H').");
            $display("Stop bit is correct.");
            $display("UART frame transmitted correctly.");

        end else begin

            $display("RESULT: FAIL");
            $display("Expected:");
            $display("  Start = 0");
            $display("  Data  = 0x48");
            $display("  Stop  = 1");
            $display("Received:");
            $display("  Start = %b", captured[0]);
            $display("  Data  = 0x%02h", captured[8:1]);
            $display("  Stop  = %b", captured[9]);

        end

        $display("==============================================");
    end

endmodule
