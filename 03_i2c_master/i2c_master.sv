
// =====================================================================
// i2c_master.sv -- Single-register I2C read master
//
// Performs one complete I2C register read:
//
// START -> Device Address + Write -> ACK -> Register Address -> ACK
// -> Repeated START -> Device Address + Read -> ACK -> Read 1 Byte
// -> Master NACK -> STOP
//
// Designed for devices such as the MPU-6050. For example, the
// MPU-6050 WHO_AM_I register is at address 0x75 and normally returns
// 0x68.
//
// The master generates four timing phases for each SCL period:
//   Tick 0: SCL low, prepare SDA
//   Tick 1: SCL low
//   Tick 2: SCL high, sample SDA
//   Tick 3: SCL high, prepare for the next bit
//
// The tick counter is reset whenever the FSM enters a new state so
// states that require a complete four-phase sequence always start
// from tick 0.
//
// Usage:
//   1. Set dev_addr and reg_addr.
//   2. Pulse start HIGH for one clock.
//   3. Wait for busy to return LOW.
//   4. If done pulses HIGH, data_out contains the received byte.
//   5. If error pulses HIGH, the slave did not acknowledge.
// =====================================================================

`timescale 1ns / 1ps

module i2c_master #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int I2C_FREQ_HZ = 400_000
) (
    input  logic       clk,
    input  logic       rst_n,

    input  logic [6:0] dev_addr,   // 7-bit I2C device address
    input  logic [7:0] reg_addr,   // Register address to read
    input  logic       start,      // One-clock pulse to start a read

    output logic [7:0] data_out,   // Received byte
    output logic       busy,       // HIGH while an I2C transaction is active
    output logic       done,       // One-clock pulse when the read succeeds
    output logic       error,      // One-clock pulse if an ACK is not received

    inout  tri         sda,        // I2C SDA line
    output logic       scl         // I2C SCL line
);

    // Four timing ticks are used for every SCL clock period.
    localparam int QUARTER_PERIOD = CLK_FREQ_HZ / (I2C_FREQ_HZ * 4);

    // Divides the system clock to generate the I2C timing ticks.
    logic [$clog2(QUARTER_PERIOD + 1)-1:0] clk_div;

    // Current timing phase within one SCL period.
    logic [1:0] tick;

    // Indicates that a new timing tick has occurred.
    logic tick_en;

    // Registered SCL output.
    logic scl_r;
    assign scl = scl_r;

    // ---------------------------------------------------------------
    // SDA open-drain interface
    //
    // I2C devices do not actively drive SDA HIGH. They either pull
    // the line LOW or release it so the external pull-up can make it
    // HIGH.
    // ---------------------------------------------------------------
    logic sda_out;
    logic sda_oe;

    assign sda = sda_oe ? sda_out : 1'bz;

    wire sda_in = sda;

    // ---------------------------------------------------------------
    // I2C transaction states
    // ---------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE,
        S_START,
        S_ADDR_W,
        S_ACK1,
        S_REG,
        S_ACK2,
        S_RSTART,
        S_ADDR_R,
        S_ACK3,
        S_READ_BYTE,
        S_MASTER_NACK,
        S_STOP,
        S_DONE,
        S_ERROR
    } state_e;

    state_e state;

    // Index used to transmit and receive bits from bit 7 to bit 0.
    logic [3:0] bit_idx;

    // Holds the byte currently being transmitted or received.
    logic [7:0] shift_reg;

    // Store the requested register and device address.
    logic [7:0] reg_addr_latched;
    logic [6:0] dev_addr_latched;

    // ---------------------------------------------------------------
    // Main I2C controller
    //
    // The clock divider and FSM are handled in the same always_ff
    // block so that timing is restarted whenever the FSM changes state.
    // ---------------------------------------------------------------
    always_ff @(posedge clk) begin

        // -------------------------------------------------------------
        // Reset
        // -------------------------------------------------------------
        if (!rst_n) begin
            state   <= S_IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            error   <= 1'b0;

            // I2C bus is idle when both SCL and SDA are HIGH.
            scl_r   <= 1'b1;
            sda_oe  <= 1'b1;
            sda_out <= 1'b1;

            clk_div <= '0;
            tick    <= 2'd0;
            tick_en <= 1'b0;

        end else begin

            // done and error are one-clock pulses.
            done  <= 1'b0;
            error <= 1'b0;

            // ---------------------------------------------------------
            // Generate the four timing ticks used by the I2C FSM.
            // ---------------------------------------------------------
            if (busy) begin

                if (clk_div == QUARTER_PERIOD - 1) begin
                    clk_div <= '0;
                    tick    <= tick + 1'b1;
                    tick_en <= 1'b1;

                end else begin
                    clk_div <= clk_div + 1'b1;
                    tick_en <= 1'b0;
                end

            end else begin
                clk_div <= '0;
                tick    <= 2'd0;
                tick_en <= 1'b0;
            end

            // ---------------------------------------------------------
            // I2C state machine
            // ---------------------------------------------------------
            case (state)

                // -----------------------------------------------------
                // IDLE
                // Wait for a new register-read request.
                // -----------------------------------------------------
                S_IDLE: begin
                    scl_r   <= 1'b1;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b1;

                    if (start) begin
                        dev_addr_latched <= dev_addr;
                        reg_addr_latched <= reg_addr;

                        busy  <= 1'b1;
                        state <= S_START;

                        // Start the new state at tick 0.
                        clk_div <= '0;
                        tick    <= 2'd0;
                        tick_en <= 1'b0;
                    end
                end

                // -----------------------------------------------------
                // START
                //
                // I2C START condition:
                // SDA changes from HIGH to LOW while SCL is HIGH.
                // -----------------------------------------------------
                S_START: begin
                    case (tick)

                        2'd0: begin
                            sda_oe  <= 1'b1;
                            sda_out <= 1'b1;
                            scl_r   <= 1'b1;
                        end

                        2'd1: begin
                            sda_out <= 1'b0;
                        end

                        2'd2: begin
                            scl_r <= 1'b0;
                        end

                        2'd3: begin
                            bit_idx   <= 4'd7;
                            shift_reg <= {dev_addr_latched, 1'b0};

                            if (tick_en) begin
                                state <= S_ADDR_W;

                                clk_div <= '0;
                                tick    <= 2'd0;
                                tick_en <= 1'b0;
                            end
                        end

                    endcase
                end

                // -----------------------------------------------------
                // DEVICE ADDRESS + WRITE
                //
                // Send the 7-bit device address followed by the
                // write bit (0), MSB first.
                // -----------------------------------------------------
                S_ADDR_W: begin
                    i2c_shift_out(shift_reg[bit_idx]);

                    if (tick_en && tick == 2'd3) begin

                        if (bit_idx == 4'd0) begin
                            state <= S_ACK1;

                            clk_div <= '0;
                            tick    <= 2'd0;
                            tick_en <= 1'b0;

                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                        end
                    end
                end

                // -----------------------------------------------------
                // ACK 1
                //
                // Release SDA so the slave can pull it LOW to
                // acknowledge the device address.
                // -----------------------------------------------------
                S_ACK1: begin
                    if (tick == 2'd0)
                        sda_oe <= 1'b0;

                    scl_r <= (tick == 2'd0 || tick == 2'd1)
                             ? 1'b0 : 1'b1;

                    if (tick_en && tick == 2'd2) begin
                        sda_oe <= 1'b1;

                        if (sda_in == 1'b0) begin
                            bit_idx   <= 4'd7;
                            shift_reg <= reg_addr_latched;
                            state     <= S_REG;
                        end else begin
                            state <= S_ERROR;
                        end

                        clk_div <= '0;
                        tick    <= 2'd0;
                        tick_en <= 1'b0;
                    end
                end

                // -----------------------------------------------------
                // REGISTER ADDRESS
                //
                // Send the register address that we want to read.
                // -----------------------------------------------------
                S_REG: begin
                    i2c_shift_out(shift_reg[bit_idx]);

                    if (tick_en && tick == 2'd3) begin

                        if (bit_idx == 4'd0) begin
                            state <= S_ACK2;

                            clk_div <= '0;
                            tick    <= 2'd0;
                            tick_en <= 1'b0;

                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                        end
                    end
                end

                // -----------------------------------------------------
                // ACK 2
                //
                // Check that the slave accepted the register address.
                // -----------------------------------------------------
                S_ACK2: begin
                    if (tick == 2'd0)
                        sda_oe <= 1'b0;

                    scl_r <= (tick == 2'd0 || tick == 2'd1)
                             ? 1'b0 : 1'b1;

                    if (tick_en && tick == 2'd2) begin
                        sda_oe <= 1'b1;

                        state <= (sda_in == 1'b0)
                                 ? S_RSTART : S_ERROR;

                        clk_div <= '0;
                        tick    <= 2'd0;
                        tick_en <= 1'b0;
                    end
                end

                // -----------------------------------------------------
                // REPEATED START
                //
                // Generate a second START without releasing the bus.
                // This changes the transaction from write mode to
                // read mode.
                // -----------------------------------------------------
                S_RSTART: begin
                    case (tick)

                        2'd0: begin
                            sda_oe  <= 1'b1;
                            sda_out <= 1'b1;
                            scl_r   <= 1'b0;
                        end

                        2'd1: begin
                            scl_r <= 1'b1;
                        end

                        2'd2: begin
                            sda_out <= 1'b0;
                        end

                        2'd3: begin
                            scl_r     <= 1'b0;
                            bit_idx   <= 4'd7;
                            shift_reg <= {dev_addr_latched, 1'b1};

                            if (tick_en) begin
                                state <= S_ADDR_R;

                                clk_div <= '0;
                                tick    <= 2'd0;
                                tick_en <= 1'b0;
                            end
                        end

                    endcase
                end

                // -----------------------------------------------------
                // DEVICE ADDRESS + READ
                //
                // Send the device address followed by the read bit (1).
                // -----------------------------------------------------
                S_ADDR_R: begin
                    i2c_shift_out(shift_reg[bit_idx]);

                    if (tick_en && tick == 2'd3) begin

                        if (bit_idx == 4'd0) begin
                            state <= S_ACK3;

                            clk_div <= '0;
                            tick    <= 2'd0;
                            tick_en <= 1'b0;

                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                        end
                    end
                end

                // -----------------------------------------------------
                // ACK 3
                //
                // The slave acknowledges the read address before
                // sending the requested data.
                // -----------------------------------------------------
                S_ACK3: begin
                    if (tick == 2'd0)
                        sda_oe <= 1'b0;

                    scl_r <= (tick == 2'd0 || tick == 2'd1)
                             ? 1'b0 : 1'b1;

                    if (tick_en && tick == 2'd2) begin

                        // SDA remains released while the slave sends data.
                        bit_idx <= 4'd7;

                        state <= (sda_in == 1'b0)
                                 ? S_READ_BYTE : S_ERROR;

                        clk_div <= '0;
                        tick    <= 2'd0;
                        tick_en <= 1'b0;
                    end
                end

                // -----------------------------------------------------
                // READ BYTE
                //
                // Release SDA and sample one bit from the slave while
                // SCL is HIGH. The byte is received MSB first.
                // -----------------------------------------------------
                S_READ_BYTE: begin
                    sda_oe <= 1'b0;

                    scl_r <= (tick == 2'd0 || tick == 2'd1)
                             ? 1'b0 : 1'b1;

                    // Sample the data while SCL is HIGH.
                    if (tick_en && tick == 2'd2) begin
                        shift_reg[bit_idx] <= sda_in;
                    end

                    // Move to the next bit after the complete bit period.
                    if (tick_en && tick == 2'd3) begin

                        if (bit_idx == 4'd0) begin
                            state <= S_MASTER_NACK;

                            clk_div <= '0;
                            tick    <= 2'd0;
                            tick_en <= 1'b0;

                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                        end
                    end
                end

                // -----------------------------------------------------
                // MASTER NACK
                //
                // The master sends NACK after receiving the requested
                // byte to tell the slave that no more data is needed.
                // -----------------------------------------------------
                S_MASTER_NACK: begin
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b1;

                    scl_r <= (tick == 2'd0 || tick == 2'd1)
                             ? 1'b0 : 1'b1;

                    if (tick_en && tick == 2'd3) begin
                        data_out <= shift_reg;
                        state    <= S_STOP;

                        clk_div <= '0;
                        tick    <= 2'd0;
                        tick_en <= 1'b0;
                    end
                end

                // -----------------------------------------------------
                // STOP
                //
                // I2C STOP condition:
                // SDA changes from LOW to HIGH while SCL is HIGH.
                // -----------------------------------------------------
                S_STOP: begin
                    case (tick)

                        2'd0: begin
                            sda_oe  <= 1'b1;
                            sda_out <= 1'b0;
                            scl_r   <= 1'b0;
                        end

                        2'd1: begin
                            scl_r <= 1'b1;
                        end

                        2'd2: begin
                            sda_out <= 1'b1;
                        end

                        2'd3: begin
                            if (tick_en) begin
                                state <= S_DONE;

                                clk_div <= '0;
                                tick    <= 2'd0;
                                tick_en <= 1'b0;
                            end
                        end

                    endcase
                end

                // -----------------------------------------------------
                // SUCCESS
                // -----------------------------------------------------
                S_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                // -----------------------------------------------------
                // ERROR
                //
                // Reached when the slave does not acknowledge one of
                // the address or register transfers.
                // -----------------------------------------------------
                S_ERROR: begin
                    busy  <= 1'b0;
                    error <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

    // ------------------------------------------------------------------
    // Drive one bit onto SDA during a write operation.
    //
    // SDA changes while SCL is LOW and remains stable while SCL is HIGH.
    // This helper is used for the device address and register address.
    // ------------------------------------------------------------------
    task automatic i2c_shift_out(input logic bit_val);

        sda_oe <= 1'b1;

        case (tick)

            2'd0: begin
                sda_out <= bit_val;
                scl_r   <= 1'b0;
            end

            2'd1: begin
                scl_r <= 1'b0;
            end

            2'd2: begin
                scl_r <= 1'b1;
            end

            2'd3: begin
                scl_r <= 1'b1;
            end

        endcase

    endtask

endmodule
