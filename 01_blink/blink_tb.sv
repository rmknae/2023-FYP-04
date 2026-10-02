
// =====================================================================
// blink_tb.sv -- testbench for blink.sv
//
// We override HALF_PERIOD down to a small number for simulation speed
// (blink.sv's real value of 50,000,000 would take far too long to
// simulate) -- no manual edit-and-revert of blink.sv needed, since
// HALF_PERIOD is a parameter this testbench overrides at instantiation.
//
// Stimulus is driven on the NEGEDGE of clk to avoid a same-timestep race
// with the DUT's own always_ff @(posedge clk) block.
// =====================================================================

`timescale 1ns / 1ps

module blink_tb;

    // Use a small value so the LED toggles quickly during simulation.
    localparam int SIM_HALF_PERIOD = 10;

    logic clk = 0;
    logic rst_n;
    logic led0;

    // Instantiate the blink module with the smaller simulation value.
    blink #(
        .HALF_PERIOD(SIM_HALF_PERIOD)
    ) dut (
        .clk,
        .rst_n,
        .led0
    );

    // 10 ns clock period = 100 MHz.
    always #5 clk = ~clk;

    int toggle_count;
    logic led0_prev;

    initial begin
        // Create waveform file for viewing in GTKWave/Vivado.
        $dumpfile("blink.vcd");
        $dumpvars(0, blink_tb);

        toggle_count = 0;
        rst_n = 0;

        $display("==============================================");
        $display("        BLINK MODULE SIMULATION START         ");
        $display("==============================================");
        $display("Clock period       : 10 ns");
        $display("Clock frequency    : 100 MHz");
        $display("HALF_PERIOD        : %0d clocks", SIM_HALF_PERIOD);
        $display("----------------------------------------------");

        // Hold reset active for a few clock cycles.
        $display("[%0t ns] Applying reset...", $time);

        @(negedge clk);
        @(negedge clk);
        @(negedge clk);

        // Release reset.
        rst_n = 1;
        led0_prev = led0;

        $display("[%0t ns] Reset released.", $time);
        $display("[%0t ns] LED0 initial state = %b", $time, led0);
        $display("----------------------------------------------");

        // Run long enough to observe several LED toggles.
        repeat (SIM_HALF_PERIOD * 8) begin
            @(posedge clk);

            // Detect every change in LED0.
            if (led0 !== led0_prev) begin
                toggle_count++;
                led0_prev = led0;

                $display(
                    "[%0t ns] LED0 toggled -> %b  |  Toggle #%0d",
                    $time,
                    led0,
                    toggle_count
                );
            end
        end

        $display("----------------------------------------------");
        $display("Simulation finished.");
        $display("Total clock cycles checked : %0d",
                 SIM_HALF_PERIOD * 8);
        $display("Total LED0 toggles         : %0d",
                 toggle_count);
        $display("Expected toggles           : approximately 8");

        // Check whether the LED toggled approximately the expected
        // number of times.
        if (toggle_count >= 6 && toggle_count <= 10) begin
            $display("RESULT: PASS");
            $display("LED0 is toggling at approximately the expected rate.");
        end
        else begin
            $display("RESULT: FAIL");
            $display("LED0 toggle count is outside the expected range.");
            $display("Check the counter and reset logic.");
        end

        $display("----------------------------------------------");
        $display("Note: HALF_PERIOD = %0d is used only for simulation.",
                 SIM_HALF_PERIOD);
        $display("Hardware uses the default HALF_PERIOD = 50,000,000.");
        $display("==============================================");

        $finish;
    end

endmodule
