module uart_transmitter (
    input  wire clk,
    input  wire rst,
    input  wire tx_start,   // pulse or held-high start request
    input  wire baud_tick,  // 1-clk pulse from baud rate generator
    input  wire [7:0] data_in,    // parallel byte to send
    output reg  tx_serial,  // serial output line
    output wire busy       // high whenever not idle
);

    // state encoding
    parameter IDLE  = 2'b00;
    parameter START = 2'b01;
    parameter DATA  = 2'b10;
    parameter STOP  = 2'b11;

    reg [1:0] state;
    reg [7:0] data_buffer;
    reg [2:0] index;

    // simple rising-edge detector for tx_start, so a held-high
    // tx_start doesn't cause repeated/unintended transmissions
    reg tx_start_d;
    wire tx_start_pulse = tx_start & ~tx_start_d;

    always @(posedge clk) begin
        if (rst)
            tx_start_d <= 1'b0;
        else
            tx_start_d <= tx_start;
    end

    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            tx_serial   <= 1'b1;   // idle line level
            index       <= 3'b0;
            data_buffer <= 8'b0;
        end else begin
            case (state)

                IDLE: begin
                    tx_serial <= 1'b1;
                    index     <= 3'b0;
                    if (tx_start_pulse) begin
                        state       <= START;
                        data_buffer <= data_in;
                    end
                end

                START: begin
                    tx_serial <= 1'b0;          // start bit
                    if (baud_tick)
                        state <= DATA;
                end

                DATA: begin
                    tx_serial <= data_buffer[index]; // LSB first
                    if (baud_tick) begin
                        if (index == 3'h7)
                            state <= STOP;
                        else
                            index <= index + 3'h1;
                    end
                end

                STOP: begin
                    tx_serial <= 1'b1;          // stop bit
                    if (baud_tick)
                        state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

    assign busy = (state != IDLE);

endmodule