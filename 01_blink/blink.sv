
// =====================================================================
// blink.sv -- LED blink module for the Arty A7-100T
//
// Uses the board's 100 MHz clock to periodically toggle LED0.
// HALF_PERIOD determines how many clock cycles occur between each
// LED state change. With the default value of 50,000,000, the LED
// toggles every 0.5 seconds, producing a 1 Hz blink rate.
//
// The active-low reset input clears the counter and turns LED0 off.
// HALF_PERIOD is a parameter so it can be overridden with a smaller
// value in the testbench for faster simulation.
// =====================================================================

`timescale 1ns / 1ps

// Blinks LED0 using the Arty A7-100T's 100 MHz clock.
// The LED changes state after every HALF_PERIOD clock cycles.

module blink #(
    // Number of clock cycles before the LED changes state.
    // 50,000,000 cycles at 100 MHz = 0.5 seconds.
    parameter int HALF_PERIOD = 50_000_000
) (
    input  logic clk,       // 100 MHz onboard clock
    input  logic rst_n,     // Active-low reset button
    output logic led0       // LED0 output
);

    // Counter used to measure the required number of clock cycles.
    logic [$clog2(HALF_PERIOD)-1:0] counter;

    // Counter and LED are updated on every rising edge of the clock.
    always_ff @(posedge clk) begin

        // Reset the counter and turn the LED off.
        if (!rst_n) begin
            counter <= '0;
            led0    <= 1'b0;

        // When the counter reaches HALF_PERIOD,
        // reset the counter and change the LED state.
        end else if (counter == HALF_PERIOD - 1) begin
            counter <= '0;
            led0    <= ~led0;

        // Otherwise, continue counting clock cycles.
        end else begin
            counter <= counter + 1'b1;
        end

    end

endmodule
