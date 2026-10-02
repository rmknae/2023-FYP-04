
// =====================================================================
// uart_tx.sv -- UART transmitter, 8N1
//
// Sends one 8-bit byte over a serial TX line using:
// 8 data bits, no parity, and 1 stop bit.
//
// The transmitter uses the system clock to generate the required baud
// rate. When send is asserted for one clock cycle, data_in is stored
// and transmitted LSB first.
//
// The tx line remains HIGH when idle. Each transmission consists of:
// one LOW start bit, eight data bits, and one HIGH stop bit.
// =====================================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic       clk,       // System clock
    input  logic       rst_n,     // Active-low reset
    input  logic [7:0] data_in,   // Byte to transmit
    input  logic       send,      // One-clock pulse to start transmission
    output logic       tx,        // UART serial output
    output logic       busy       // HIGH while transmission is in progress
);

    // Number of system clock cycles required for one UART bit.
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    // UART transmission states.
    typedef enum logic [1:0] {
        S_IDLE,     // Waiting for a new byte
        S_START,    // Sending the start bit
        S_DATA,     // Sending the 8 data bits
        S_STOP      // Sending the stop bit
    } state_e;

    state_e state;

    // Counts system clock cycles for the current UART bit.
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;

    // Selects which data bit is currently being transmitted.
    logic [2:0] bit_index;

    // Stores the byte being transmitted.
    logic [7:0] data_reg;

    always_ff @(posedge clk) begin

        // Reset the transmitter to the idle state.
        if (!rst_n) begin
            state     <= S_IDLE;
            tx        <= 1'b1;
            busy      <= 1'b0;
            clk_count <= '0;
            bit_index <= '0;

        end else begin

            case (state)

                // -----------------------------------------------------
                // IDLE
                // Wait for send to start a new transmission.
                // -----------------------------------------------------
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;

                    if (send) begin
                        // Store the byte before transmission begins.
                        data_reg  <= data_in;
                        busy      <= 1'b1;
                        state     <= S_START;
                        clk_count <= '0;
                    end
                end

                // -----------------------------------------------------
                // START BIT
                // UART start bit is LOW for one complete bit period.
                // -----------------------------------------------------
                S_START: begin
                    tx <= 1'b0;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        bit_index <= '0;
                        state     <= S_DATA;
                    end
                end

                // -----------------------------------------------------
                // DATA BITS
                // Send all 8 bits from bit 0 to bit 7.
                // UART transmits the least significant bit first.
                // -----------------------------------------------------
                S_DATA: begin
                    tx <= data_reg[bit_index];

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;

                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            state <= S_STOP;
                        end
                    end
                end

                // -----------------------------------------------------
                // STOP BIT
                // UART stop bit is HIGH for one complete bit period.
                // -----------------------------------------------------
                S_STOP: begin
                    tx <= 1'b1;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        busy      <= 1'b0;
                        state     <= S_IDLE;
                    end
                end

                // Return to idle if an invalid state occurs.
                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
