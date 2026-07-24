module uart_receiver (
    input  wire clk,
    input  wire rst,
    input  wire ready_clear,   // clears the ready flag after read
    input  wire baud_tick16x,  // 16x oversample tick from baud generator
    input  wire rx_serial,     // incoming serial line
    output reg ready,         // high when a byte is ready
    output reg  [7:0] data_out       // received byte
);

    parameter IDLE  = 2'b00;
    parameter START = 2'b01;
    parameter DATA  = 2'b10;
    parameter STOP  = 2'b11;

    reg [1:0] state;
    reg [3:0] tick_count;  // 0-15, ticks within current bit
    reg [2:0] bit_index;   // which of the 8 data bits
    reg [7:0] temp_reg;    // shift-in buffer

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            ready      <= 1'b0;
            data_out   <= 8'd0;
            tick_count <= 4'd0;
            bit_index  <= 3'd0;
            temp_reg   <= 8'd0;
        end else begin

            if (ready_clear)
                ready <= 1'b0;

            case (state)

                IDLE: begin
                    tick_count <= 4'd0;
                    bit_index  <= 3'd0;
                    if (!rx_serial)            // possible start bit
                        state <= START;
                end

                START: begin
                    // wait to the middle of the start bit (8 of 16 ticks)
                    if (baud_tick16x) begin
                        if (tick_count == 4'd7) begin
                            tick_count <= 4'd0;
                            if (!rx_serial)     // confirm still low -> real start bit
                                state <= DATA;
                            else
                                state <= IDLE;  // was a glitch, bail out
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                DATA: begin
                    // one full 16-tick window per bit -> samples land mid-bit
                    if (baud_tick16x) begin
                        if (tick_count == 4'd15) begin
                            temp_reg[bit_index] <= rx_serial;
                            tick_count <= 4'd0;
                            if (bit_index == 3'd7)
                                state <= STOP;
                            else
                                bit_index <= bit_index + 1'b1;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick16x) begin
                        if (tick_count == 4'd15) begin
                            state    <= IDLE;
                            ready    <= 1'b1;
                            data_out <= temp_reg;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule