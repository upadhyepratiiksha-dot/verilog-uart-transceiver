`timescale 1ns / 1ps

module uart_top_tb;

    reg clk;
    reg rst;

    // transmitter side
    reg  tx_start;
    reg  [7:0] tx_data_in;
    wire tx;
    wire busy;

    // receiver side
    reg  ready_clear;
    wire ready;
    wire [7:0] rx_data_out;

    integer fail_count = 0;

    // 1. Instantiate the full UART (loopback: tx wired straight to rx_serial)
    uart_top DUT (
        .clk(clk),
        .rst(rst),

        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx(tx),
        .busy(busy),

        .ready_clear(ready_clear),
        .rx_serial(tx),          // <-- loopback: receiver listens to transmitter's line
        .ready(ready),
        .rx_data_out(rx_data_out)
    );

    initial begin
        $dumpfile("waveform_top.vcd");
        $dumpvars(0, uart_top_tb);
    end

    // 2. System Clock Generation (50 MHz, 20ns period)
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // 3. Self-checking compare helper
    task check_byte(input integer tc_num, input [7:0] expected, input [7:0] actual);
        begin
            if (actual !== expected) begin
                $display("[TC%0d] FAIL - got 0x%h, expected 0x%h (time=%0t)", tc_num, actual, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("[TC%0d] PASS - got 0x%h (time=%0t)", tc_num, actual, $time);
            end
        end
    endtask

    // 4. Task: send one byte through the transmitter and wait for the
    //    receiver to flag it ready, then check + clear
    task send_and_check(input integer tc_num, input [7:0] byte_to_send);
        begin
            @(posedge clk);
            tx_data_in = byte_to_send;
            tx_start   = 1'b1;
            @(posedge clk);
            tx_start   = 1'b0;

            $display("[TC%0d] Sending byte 0x%h at time %0t", tc_num, byte_to_send, $time);

            // wait for the receiver to signal a completed frame
            wait (ready === 1'b1);
            #1;
            check_byte(tc_num, byte_to_send, rx_data_out);

            // clear ready flag before the next frame
            @(posedge clk);
            ready_clear = 1'b1;
            @(posedge clk);
            ready_clear = 1'b0;

            // wait for transmitter to fully return to idle before next send
            wait (busy === 1'b0);
        end
    endtask

    initial begin
        // Initialize
        clk         = 1'b0;
        rst         = 1'b1;
        tx_start    = 1'b0;
        tx_data_in  = 8'h00;
        ready_clear = 1'b0;

        #100;
        @(posedge clk);
        rst = 1'b0;
        $display("[TB INFO] Reset deactivated at time %t", $time);

        #1;
        if (tx !== 1'b1)
            $display("[TB FAIL] tx line not idle-high after reset (got %b)", tx);
        else
            $display("[TB PASS] tx line idle-high after reset");
        if (busy !== 1'b0)
            $display("[TB FAIL] busy asserted after reset");
        else
            $display("[TB PASS] busy low after reset");
        if (ready !== 1'b0)
            $display("[TB FAIL] ready asserted after reset");
        else
            $display("[TB PASS] ready low after reset");

        #200;

        // --- Loopback test cases ---
        send_and_check(1, 8'hA5);
        send_and_check(2, 8'h00);
        send_and_check(3, 8'hFF);
        send_and_check(4, 8'h55);
        send_and_check(5, 8'h3C);

        // --- Back-to-back test: start next byte immediately, no gap ---
        @(posedge clk);
        tx_data_in = 8'h81;
        tx_start   = 1'b1;
        @(posedge clk);
        tx_start   = 1'b0;
        $display("[TC6] Sending byte 0x%h (back-to-back timing) at time %0t", 8'h81, $time);
        wait (ready === 1'b1);
        #1;
        check_byte(6, 8'h81, rx_data_out);
        @(posedge clk);
        ready_clear = 1'b1;
        @(posedge clk);
        ready_clear = 1'b0;
        wait (busy === 1'b0);

        #5000;

        // Final summary
        if (fail_count == 0)
            $display("[TB RESULT] ALL TESTS PASSED");
        else
            $display("[TB RESULT] %0d TEST(S) FAILED", fail_count);

        $display("[TB INFO] Simulation Complete.");
        $finish;
    end

    // 5. Safety timeout in case something hangs (e.g. ready never asserts)
    initial begin
        #10_000_000; // 10ms of sim time is far more than enough for a few bytes at 9600 baud
        $display("[TB FAIL] TIMEOUT - simulation did not finish in time, check for a hang");
        $finish;
    end

endmodule