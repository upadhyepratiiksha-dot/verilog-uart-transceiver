`timescale 1ns / 1ps

module uart_transmitter_tb;

    // 1. Declare Inputs as registers (regs) and Outputs as wires
    reg clk;
    reg tx_start;
    reg baud_tick;
    reg rst;
    reg [7:0] data_in;

    wire tx_serial;
    wire busy;

    // pass/fail bookkeeping
    integer fail_count = 0;
    integer i;

    // 2. Instantiate the Device Under Test (DUT)
    uart_transmitter DUT (
        .clk(clk),
        .tx_start(tx_start),
        .baud_tick(baud_tick),
        .rst(rst),
        .data_in(data_in),
        .tx_serial(tx_serial),
        .busy(busy)
    );

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, uart_transmitter_tb);
    end

    // 3. System Clock Generation (50 MHz)
    // Period = 1 / 50MHz = 20ns. Toggle every 10ns.
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // 4. Baud Rate Generator Emulation (9600 Baud)
    // Matches baudrate_generator.v exactly: counts 0..5208 inclusive
    // (5209 states), wrapping and pulsing tx_enb when counter == 0.
    // Here we pulse baud_tick the cycle AFTER reaching 5208, i.e. on
    // the wrap, which lines up with tx_enb == (tx_counter == 0).
    reg [12:0] clk_count;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_tick <= 1'b0;
            clk_count <= 13'd0;
        end else begin
            if (clk_count == 13'd5208) begin
                baud_tick <= 1'b1;
                clk_count <= 13'd0;
            end else begin
                baud_tick <= 1'b0;
                clk_count <= clk_count + 1'b1;
            end
        end
    end

    // 5. Task to encapsulate a full Baud Tick wait (helps keep clean stimulus timing)
    task wait_baud_ticks(input integer count);
        integer j;
        begin
            for (j = 0; j < count; j = j + 1) begin
                @(posedge baud_tick);
            end
            @(posedge clk); // Align back slightly with system clock
            #1;             // let signals settle before sampling
        end
    endtask

    // 6. Self-checking bit compare helper
    // bit_num: -1 for start bit, -2 for stop bit, 0..7 for data bit index
    // tc_num : test case number, printed alongside for context
    task check_bit(input integer bit_num, input integer tc_num, input expected);
        begin
            if (bit_num == -1)
                $write("[TC%0d] Start Bit      : ", tc_num);
            else if (bit_num == -2)
                $write("[TC%0d] Stop Bit       : ", tc_num);
            else
                $write("[TC%0d] Data Bit %0d     : ", tc_num, bit_num);

            if (tx_serial !== expected) begin
                $display("FAIL - got %b, expected %b (time=%0t)", tx_serial, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS - got %b (time=%0t)", tx_serial, $time);
            end
        end
    endtask

    // 7. Stimulus Generation
    reg [7:0] expected_byte;

    initial begin
        // Initialize Signals
        clk       = 1'b0;
        tx_start  = 1'b0;
        rst       = 1'b1;
        data_in   = 8'h00;

        // Hold Reset for 100ns to let hardware settle
        #100;
        @(posedge clk);
        rst = 1'b0;
        $display("[TB INFO] Reset deactivated at time %t", $time);

        // Check idle-state outputs right after reset
        #1;
        if (tx_serial !== 1'b1)
            $display("[FAIL] Idle line level: got %b, expected 1", tx_serial);
        else
            $display("[PASS] Idle line level correct (1)");
        if (busy !== 1'b0)
            $display("[FAIL] Idle busy flag: got %b, expected 0", busy);
        else
            $display("[PASS] Idle busy flag correct (0)");

        // Wait a few cycles in IDLE
        #200;

        // --- TEST CASE 1: Transmit Byte 8'hA5 (Binary: 10100101) ---
        expected_byte = 8'hA5; // LSB first: 1,0,1,0,0,1,0,1

        @(posedge clk);
        data_in  = expected_byte;
        tx_start = 1'b1;  // Request transmission

        @(posedge clk);
        tx_start = 1'b0;  // De-assert start (single clock pulse behavior)
        $display("[TB INFO] Transmission started for data 0x%h", data_in);

        #1;
        if (busy !== 1'b1)
            $display("[FAIL] busy did not assert after tx_start");
        else
            $display("[PASS] busy asserted after tx_start");

        // Start bit
        wait_baud_ticks(1);
        check_bit(-1, 1, 1'b0);

        // 8 data bits, LSB first
        for (i = 0; i < 8; i = i + 1) begin
            wait_baud_ticks(1);
            check_bit(i, 1, expected_byte[i]);
        end

        // Stop bit
        wait_baud_ticks(1);
        check_bit(-2, 1, 1'b1);

        #1;
        if (busy !== 1'b0)
            $display("[FAIL] busy did not clear after stop bit");
        else
            $display("[PASS] busy cleared after stop bit");

        // --- TEST CASE 2: Transmit Byte 8'h00 (all zero data bits) ---
        expected_byte = 8'h00;
        @(posedge clk);
        data_in  = expected_byte;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;
        $display("[TB INFO] Transmission started for data 0x%h", data_in);

        wait_baud_ticks(1);
        check_bit(-1, 2, 1'b0);
        for (i = 0; i < 8; i = i + 1) begin
            wait_baud_ticks(1);
            check_bit(i, 2, expected_byte[i]);
        end
        wait_baud_ticks(1);
        check_bit(-2, 2, 1'b1);

        // --- TEST CASE 3: Transmit Byte 8'hFF (all one data bits) ---
        expected_byte = 8'hFF;
        @(posedge clk);
        data_in  = expected_byte;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;
        $display("[TB INFO] Transmission started for data 0x%h", data_in);

        wait_baud_ticks(1);
        check_bit(-1, 3, 1'b0);
        for (i = 0; i < 8; i = i + 1) begin
            wait_baud_ticks(1);
            check_bit(i, 3, expected_byte[i]);
        end
        wait_baud_ticks(1);
        check_bit(-2, 3, 1'b1);

        #2000;

        // Final summary
        if (fail_count == 0)
            $display("[TB RESULT] ALL TESTS PASSED");
        else
            $display("[TB RESULT] %0d TEST(S) FAILED", fail_count);

        $display("[TB INFO] Simulation Complete.");
        $finish;
    end

endmodule
