// =====================================================================
// i2c_master_tb.sv -- testbench for i2c_master.sv
//
// Tests the I2C master using a simple behavioral MPU-6050 model.
// The slave acknowledges the device address and register address,
// then returns 0x68 when the WHO_AM_I register (0x75) is read.
//
// The testbench checks that the master completes the transaction
// successfully and receives the expected WHO_AM_I value.
//
// =====================================================================

`timescale 1ns / 1ps

module i2c_master_tb;

    // Testbench signals
    logic       clk = 0;
    logic       rst_n;
    logic [6:0] dev_addr;
    logic [7:0] reg_addr;
    logic       start;
    logic [7:0] data_out;
    logic       busy;
    logic       done;
    logic       error;

    wire scl;
    wire sda;

    // Use a smaller clock frequency for faster simulation.
    // The I2C master still uses the same clock-to-I2C frequency ratio.
    i2c_master #(
        .CLK_FREQ_HZ (1_000_000),
        .I2C_FREQ_HZ (100_000)
    ) dut (
        .clk,
        .rst_n,
        .dev_addr,
        .reg_addr,
        .start,
        .data_out,
        .busy,
        .done,
        .error,
        .sda,
        .scl
    );

    // 1 MHz test clock: 500 ns HIGH + 500 ns LOW.
    always #500 clk = ~clk;


    // ------------------------------------------------------------------
    // Behavioral MPU-6050 slave
    //
    // The slave:
    //   - ACKs the device address
    //   - ACKs the register address
    //   - ACKs the read address
    //   - Sends 0x68 as the WHO_AM_I value
    //
    // This is only a simulation model and is not synthesizable.
    // ------------------------------------------------------------------

    logic slave_drive;
    logic slave_sda_val;

    // I2C SDA is an open-drain line.
    // The slave drives it LOW when required and otherwise releases it.
    assign sda = slave_drive ? slave_sda_val : 1'bz;

    // Value returned by the simulated WHO_AM_I register.
    logic [7:0] who_am_i_value = 8'h68;

    // Generate the slave response based on the master's current state.
    always_comb begin

        // Default: release SDA.
        slave_drive   = 1'b0;
        slave_sda_val = 1'b1;

        // ACK the master's address and register bytes.
        if (dut.state == dut.S_ACK1 ||
            dut.state == dut.S_ACK2 ||
            dut.state == dut.S_ACK3) begin

            slave_drive   = 1'b1;
            slave_sda_val = 1'b0;

        // Send the WHO_AM_I byte during the read operation.
        end else if (dut.state == dut.S_READ_BYTE) begin

            slave_drive   = 1'b1;
            slave_sda_val = who_am_i_value[dut.bit_idx];

        end
    end


    // ------------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------------

    initial begin

        // Create waveform file for GTKWave.
        $dumpfile("i2c_master.vcd");
        $dumpvars(0, i2c_master_tb);

        // Display simulation configuration.
        $display("");
        $display("==============================================");
        $display("       I2C MASTER SIMULATION START");
        $display("==============================================");
        $display("Clock frequency    : 1 MHz");
        $display("I2C frequency      : 100 kHz");
        $display("Device address     : 0x68");
        $display("Register address   : 0x75");
        $display("Expected data      : 0x68");
        $display("----------------------------------------------");

        // Initial values.
        rst_n    = 0;
        dev_addr = 7'h68;
        reg_addr = 8'h75;
        start    = 0;

        $display("[%0t ns] Applying reset...", $time);

        // Hold reset for a few clock cycles.
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);

        rst_n = 1;

        $display("[%0t ns] Reset released.", $time);
        $display("[%0t ns] Starting I2C transaction...", $time);

        @(negedge clk);

        // Generate a one-clock start pulse.
        start = 1;
        $display("[%0t ns] START pulse asserted.", $time);

        @(negedge clk);
        start = 0;

        $display("[%0t ns] START pulse released.", $time);
        $display("[%0t ns] Waiting for I2C transaction to complete...", $time);

        // Wait until the master reports either success or an error.
        wait (done || error);

        $display("----------------------------------------------");

        // Check the result.
        if (done) begin

            $display("[%0t ns] I2C transaction completed.", $time);
            $display("[%0t ns] Data received = 0x%02h", $time, data_out);

            if (data_out == 8'h68) begin
                $display("RESULT: PASS");
                $display("WHO_AM_I value matches the expected 0x68.");
            end else begin
                $display("RESULT: FAIL");
                $display("Expected 0x68, but received 0x%02h.", data_out);
            end

        end else begin

            $display("[%0t ns] I2C transaction reported an error.", $time);
            $display("RESULT: FAIL");
            $display("The master did not receive the expected ACK.");
        end

        $display("==============================================");
        $display("       I2C MASTER SIMULATION END");
        $display("==============================================");
        $display("");

        // Allow a few more clock cycles before ending.
        repeat (10) @(posedge clk);

        $finish;
    end


    // ------------------------------------------------------------------
    // Simulation timeout
    //
    // Stops the simulation if the I2C master gets stuck in a state.
    // ------------------------------------------------------------------

    initial begin

        #500000;

        $display("");
        $display("==============================================");
        $display("RESULT: FAIL -- SIMULATION TIMEOUT");
        $display("The I2C master did not complete the transaction.");
        $display("Current FSM state = %0d", dut.state);
        $display("==============================================");
        $display("");

        $finish;
    end

endmodule// =====================================================================
// i2c_master_tb.sv -- testbench for i2c_master.sv
//
// Tests the I2C master using a simple behavioral MPU-6050 model.
// The slave acknowledges the device address and register address,
// then returns 0x68 when the WHO_AM_I register (0x75) is read.
//
// The testbench checks that the master completes the transaction
// successfully and receives the expected WHO_AM_I value.
//
// Simulation:
//   iverilog -g2012 -o i2c_sim i2c_master_tb.sv i2c_master.sv
//   vvp i2c_sim
//   gtkwave i2c_master.vcd
// =====================================================================

`timescale 1ns / 1ps

module i2c_master_tb;

    // Testbench signals
    logic       clk = 0;
    logic       rst_n;
    logic [6:0] dev_addr;
    logic [7:0] reg_addr;
    logic       start;
    logic [7:0] data_out;
    logic       busy;
    logic       done;
    logic       error;

    wire scl;
    wire sda;

    // Use a smaller clock frequency for faster simulation.
    // The I2C master still uses the same clock-to-I2C frequency ratio.
    i2c_master #(
        .CLK_FREQ_HZ (1_000_000),
        .I2C_FREQ_HZ (100_000)
    ) dut (
        .clk,
        .rst_n,
        .dev_addr,
        .reg_addr,
        .start,
        .data_out,
        .busy,
        .done,
        .error,
        .sda,
        .scl
    );

    // 1 MHz test clock: 500 ns HIGH + 500 ns LOW.
    always #500 clk = ~clk;


    // ------------------------------------------------------------------
    // Behavioral MPU-6050 slave
    //
    // The slave:
    //   - ACKs the device address
    //   - ACKs the register address
    //   - ACKs the read address
    //   - Sends 0x68 as the WHO_AM_I value
    //
    // This is only a simulation model and is not synthesizable.
    // ------------------------------------------------------------------

    logic slave_drive;
    logic slave_sda_val;

    // I2C SDA is an open-drain line.
    // The slave drives it LOW when required and otherwise releases it.
    assign sda = slave_drive ? slave_sda_val : 1'bz;

    // Value returned by the simulated WHO_AM_I register.
    logic [7:0] who_am_i_value = 8'h68;

    // Generate the slave response based on the master's current state.
    always_comb begin

        // Default: release SDA.
        slave_drive   = 1'b0;
        slave_sda_val = 1'b1;

        // ACK the master's address and register bytes.
        if (dut.state == dut.S_ACK1 ||
            dut.state == dut.S_ACK2 ||
            dut.state == dut.S_ACK3) begin

            slave_drive   = 1'b1;
            slave_sda_val = 1'b0;

        // Send the WHO_AM_I byte during the read operation.
        end else if (dut.state == dut.S_READ_BYTE) begin

            slave_drive   = 1'b1;
            slave_sda_val = who_am_i_value[dut.bit_idx];

        end
    end


    // ------------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------------

    initial begin

        // Create waveform file for GTKWave.
        $dumpfile("i2c_master.vcd");
        $dumpvars(0, i2c_master_tb);

        // Display simulation configuration.
        $display("");
        $display("==============================================");
        $display("       I2C MASTER SIMULATION START");
        $display("==============================================");
        $display("Clock frequency    : 1 MHz");
        $display("I2C frequency      : 100 kHz");
        $display("Device address     : 0x68");
        $display("Register address   : 0x75");
        $display("Expected data      : 0x68");
        $display("----------------------------------------------");

        // Initial values.
        rst_n    = 0;
        dev_addr = 7'h68;
        reg_addr = 8'h75;
        start    = 0;

        $display("[%0t ns] Applying reset...", $time);

        // Hold reset for a few clock cycles.
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);

        rst_n = 1;

        $display("[%0t ns] Reset released.", $time);
        $display("[%0t ns] Starting I2C transaction...", $time);

        @(negedge clk);

        // Generate a one-clock start pulse.
        start = 1;
        $display("[%0t ns] START pulse asserted.", $time);

        @(negedge clk);
        start = 0;

        $display("[%0t ns] START pulse released.", $time);
        $display("[%0t ns] Waiting for I2C transaction to complete...", $time);

        // Wait until the master reports either success or an error.
        wait (done || error);

        $display("----------------------------------------------");

        // Check the result.
        if (done) begin

            $display("[%0t ns] I2C transaction completed.", $time);
            $display("[%0t ns] Data received = 0x%02h", $time, data_out);

            if (data_out == 8'h68) begin
                $display("RESULT: PASS");
                $display("WHO_AM_I value matches the expected 0x68.");
            end else begin
                $display("RESULT: FAIL");
                $display("Expected 0x68, but received 0x%02h.", data_out);
            end

        end else begin

            $display("[%0t ns] I2C transaction reported an error.", $time);
            $display("RESULT: FAIL");
            $display("The master did not receive the expected ACK.");
        end

        $display("==============================================");
        $display("       I2C MASTER SIMULATION END");
        $display("==============================================");
        $display("");

        // Allow a few more clock cycles before ending.
        repeat (10) @(posedge clk);

        $finish;
    end


    // ------------------------------------------------------------------
    // Simulation timeout
    //
    // Stops the simulation if the I2C master gets stuck in a state.
    // ------------------------------------------------------------------

    initial begin

        #500000;

        $display("");
        $display("==============================================");
        $display("RESULT: FAIL -- SIMULATION TIMEOUT");
        $display("The I2C master did not complete the transaction.");
        $display("Current FSM state = %0d", dut.state);
        $display("==============================================");
        $display("");

        $finish;
    end

endmodule