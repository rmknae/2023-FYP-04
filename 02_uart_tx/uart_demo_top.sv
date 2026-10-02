
// =====================================================================
// uart_demo_top.sv -- UART hardware test for uart_tx.sv
//
// Press BTN0 to send the character 'H' through the board's USB-UART
// interface. Configure the serial terminal for 115200 baud, 8 data
// bits, no parity, and 1 stop bit (115200 8N1).
//
// BTN0 is synchronized to the system clock and a rising-edge detector
// generates a single-cycle pulse for each button press. The UART send
// is allowed only when the transmitter is not busy.
// =====================================================================

`timescale 1ns / 1ps

module uart_demo_top (
    input  logic clk,       // 100 MHz onboard clock
    input  logic rst_n,     // Active-low reset
    input  logic btn0,      // Button used to trigger a UART transmission
    output logic uart_txd   // UART TX output to the USB-UART bridge
);

    // Synchronize BTN0 to the 100 MHz clock and detect its rising edge.
    logic btn0_sync0;
    logic btn0_sync1;
    logic btn0_prev;

    always_ff @(posedge clk) begin
        btn0_sync0 <= btn0;
        btn0_sync1 <= btn0_sync0;
        btn0_prev  <= btn0_sync1;
    end

    // Generates a one-clock-cycle pulse when BTN0 is pressed.
    wire btn0_pressed = btn0_sync1 & ~btn0_prev;

    // Indicates whether the UART transmitter is currently sending data.
    logic busy;

    // UART transmitter configured for 115200 baud.
    uart_tx #(
        .CLK_FREQ_HZ(100_000_000),
        .BAUD_RATE  (115_200)
    ) tx_inst (
        .clk,
        .rst_n,
        .data_in(8'h48),              // ASCII code for 'H'
        .send(btn0_pressed & ~busy),  // Send only when UART is idle
        .tx(uart_txd),
        .busy
    );

endmodule
