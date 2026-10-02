
// =====================================================================
// who_am_i_top.sv -- MPU-6050 WHO_AM_I hardware test
//
// Press BTN0 to start an I2C read of the MPU-6050 WHO_AM_I register.
// The received byte is then sent to the PC through the USB-UART
// interface at 115200 baud.
//
// MPU-6050:
//   Device address : 0x68
//   WHO_AM_I       : 0x75
//   Expected value : 0x68
//
// UART settings:
//   Baud rate      : 115200
//   Format         : 8N1
//
// I2C connections require pull-up resistors on SDA and SCL.
// =====================================================================

`timescale 1ns / 1ps

module who_am_i_top (
    input  logic clk,       // 100 MHz onboard clock
    input  logic rst_n,     // Active-low reset
    input  logic btn0,      // Button to start the sensor read
    inout  tri   sda,       // I2C data line
    output logic scl,       // I2C clock line
    output logic uart_txd   // UART transmit output
);

    // ---------------------------------------------------------------
    // BTN0 synchronization and edge detection
    //
    // The button is synchronized to the system clock before being
    // used by the I2C controller. A rising-edge detector generates
    // a one-clock pulse for each button press.
    // ---------------------------------------------------------------
    logic btn0_sync0;
    logic btn0_sync1;
    logic btn0_prev;

    always_ff @(posedge clk) begin
        btn0_sync0 <= btn0;
        btn0_sync1 <= btn0_sync0;
        btn0_prev  <= btn0_sync1;
    end

    wire btn0_pressed = btn0_sync1 & ~btn0_prev;

    // ---------------------------------------------------------------
    // I2C master
    //
    // Reads register 0x75 from the MPU-6050 at address 0x68.
    // ---------------------------------------------------------------
    logic [7:0] i2c_data;
    logic       i2c_busy;
    logic       i2c_done;
    logic       i2c_error;

    i2c_master #(
        .CLK_FREQ_HZ(100_000_000),
        .I2C_FREQ_HZ(400_000)
    ) i2c_inst (
        .clk,
        .rst_n,

        .dev_addr(7'h68),       // MPU-6050 I2C address
        .reg_addr(8'h75),       // WHO_AM_I register
        .start(btn0_pressed & ~i2c_busy),

        .data_out(i2c_data),
        .busy(i2c_busy),
        .done(i2c_done),
        .error(i2c_error),

        .sda,
        .scl
    );

    // ---------------------------------------------------------------
    // UART transmitter
    //
    // Sends the I2C result to the PC using 115200 baud, 8N1.
    // ---------------------------------------------------------------
    logic       uart_busy;
    logic [7:0] uart_byte;
    logic       uart_send;

    uart_tx #(
        .CLK_FREQ_HZ(100_000_000),
        .BAUD_RATE(115_200)
    ) uart_inst (
        .clk,
        .rst_n,
        .data_in(uart_byte),
        .send(uart_send),
        .tx(uart_txd),
        .busy(uart_busy)
    );

    // ---------------------------------------------------------------
    // Connect the I2C result to the UART transmitter.
    //
    // When the I2C read succeeds, send the received byte.
    // If the I2C transaction fails, send 'E' instead.
    // ---------------------------------------------------------------
    always_ff @(posedge clk) begin

        if (!rst_n) begin
            uart_send <= 1'b0;
            uart_byte <= 8'h00;

        end else begin

            // uart_send is a one-clock pulse.
            uart_send <= 1'b0;

            if (i2c_done) begin
                // Send the byte received from the MPU-6050.
                uart_byte <= i2c_data;
                uart_send <= 1'b1;

            end else if (i2c_error) begin
                // Send 'E' to indicate an I2C communication error.
                uart_byte <= 8'h45;
                uart_send <= 1'b1;
            end

        end
    end

endmodule
