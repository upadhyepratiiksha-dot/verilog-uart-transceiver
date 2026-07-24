`timescale 1ns / 1ps

module uart_receiver_tb;

    reg clk;
    reg rst;
    reg ready_clear;
    reg baud_tick16x;
    reg rx_serial;

    wire ready;
    wire [7:0] data_out;

    integer fail_count = 0;

    // 1. Instantiate the DUT
    uart_receiver DUT (
        .clk(clk),
        .rst(rst),
        .ready_clear(ready_clear),
        .baud_tick16x(baud_tick16x),
        .rx_serial(rx_serial),
        .ready(ready),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("waveform_rx.vcd");
        $dumpvars(0, uart_receiver_tb);
    end

    // 2. System Clock Generation (50 MHz, 20ns period)
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // 3. Baud Rate Generator Emulation, 16x oversample tick
    // Matches baudrate_generator.v: counts 0..325 inclusive (326 states),
    // pulses when counter wraps back to 0.
    reg [9:0] clk_count;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_tick16x <= 1'b0;
            clk_count    <= 10'd0;
        end else begin
            if (clk_count == 10'd325) begin
                baud_tick16x <= 1'b1;
                clk_count    <= 10'd0;
            end else begin
                baud_tick16x <= 1'b0;
                clk_count    <= clk_count + 1'b1;
            end
        end
    end

    // 4. Task: wait for N baud16x ticks
    task wait_ticks16(input integer count);
        integer j;
        begin
            for (j = 0; j < count; j = j + 1) begin
                @(posedge baud_tick16x);
            end
        end
    endtask

    // 5. Task: drive one UART frame (start bit, 8 data bits LSB first, stop bit)
    //    onto rx_serial, one bit held for 16 baud16x ticks each, matching
    //    real-world timing that the DUT expects to sample mid-bit.
    task send_uart_byte(input [7:0] byte_to_send);
        integer k;
        begin
            // start bit
            rx_serial = 1'b0;
            wait_ticks16(16);

            // 8 data bits, LSB first
            for (k = 0; k < 8; k = k + 1) begin
                rx_serial = byte_to_send[k];
                wait_ticks16(16);
            end

            // stop bit
            rx_serial = 1'b1;
            wait_ticks16(16);
        end
    endtask

    // 6. Self-checking compare helper
    task check_byte(input [127:0] label, input [7:0] expected, input [7:0] actual);
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s: got 0x%h, expected 0x%h (time=%0t)", label, actual, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %0s: got 0x%h (time=%0t)", label, actual, $time);
            end
        end
    endtask

    reg [7:0] test_byte;

    initial begin
        // Initialize
        clk          = 1'b0;
        rst          = 1'b1;
        ready_clear  = 1'b0;
        rx_serial    = 1'b1; // idle line level
        clk_count    = 10'd0;

        #100;
        @(posedge clk);
        rst = 1'b0;
        $display("[TB INFO] Reset deactivated at time %t", $time);

        #1;
        if (ready !== 1'b0)
            $display("[FAIL] ready asserted before any frame received");
        else
            $display("[PASS] ready correctly low after reset");

        // --- TEST CASE 1: Receive 0xA5 (10100101, LSB first: 1,0,1,0,0,1,0,1) ---
        test_byte = 8'hA5;
        $display("[TB INFO] Sending byte 0x%h", test_byte);
        send_uart_byte(test_byte);

        // wait for ready to assert
        wait (ready === 1'b1);
        #1;
        check_byte("Received Byte (TC1)", test_byte, data_out);

        // clear ready flag
        @(posedge clk);
        ready_clear = 1'b1;
        @(posedge clk);
        ready_clear = 1'b0;
        #1;
        if (ready !== 1'b0)
            $display("[FAIL] ready did not clear after ready_clear pulse");
        else
            $display("[PASS] ready cleared after ready_clear pulse");

        // small idle gap between frames
        wait_ticks16(4);

        // --- TEST CASE 2: Receive 0x00 ---
        test_byte = 8'h00;
        $display("[TB INFO] Sending byte 0x%h", test_byte);
        send_uart_byte(test_byte);
        wait (ready === 1'b1);
        #1;
        check_byte("Received Byte (TC2)", test_byte, data_out);

        @(posedge clk);
        ready_clear = 1'b1;
        @(posedge clk);
        ready_clear = 1'b0;

        wait_ticks16(4);

        // --- TEST CASE 3: Receive 0xFF ---
        test_byte = 8'hFF;
        $display("[TB INFO] Sending byte 0x%h", test_byte);
        send_uart_byte(test_byte);
        wait (ready === 1'b1);
        #1;
        check_byte("Received Byte (TC3)", test_byte, data_out);

        @(posedge clk);
        ready_clear = 1'b1;
        @(posedge clk);
        ready_clear = 1'b0;

        wait_ticks16(4);

        // --- TEST CASE 4: Receive 0x55 (01010101) ---
        test_byte = 8'h55;
        $display("[TB INFO] Sending byte 0x%h", test_byte);
        send_uart_byte(test_byte);
        wait (ready === 1'b1);
        #1;
        check_byte("Received Byte (TC4)", test_byte, data_out);

        #2000;

        if (fail_count == 0)
            $display("[TB RESULT] ALL TESTS PASSED");
        else
            $display("[TB RESULT] %0d TEST(S) FAILED", fail_count);

        $display("[TB INFO] Simulation Complete.");
        $finish;
    end

endmodule