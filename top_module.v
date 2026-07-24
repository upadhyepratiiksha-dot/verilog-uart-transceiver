module uart_top (
    input  wire clk,
    input  wire rst,

    // transmitter side
    input  wire tx_start,
    input  wire [7:0]  tx_data_in,
    output wire tx,
    output wire busy,

    // receiver side
    input  wire ready_clear,
    input  wire rx_serial,
    output wire ready,
    output wire [7:0]  rx_data_out
);

    // internal wires
    wire baud_tick_tx;   // 1x tick for transmitter
    wire baud_tick_rx;   // 16x tick for receiver oversampling

    baudrate_generator inst1 (
        .clk    (clk),
        .rst    (rst),
        .tx_enb (baud_tick_tx),
        .rx_enb (baud_tick_rx)
    );

    uart_transmitter inst2 (
        .clk       (clk),
        .rst       (rst),
        .tx_start  (tx_start),
        .data_in   (tx_data_in),
        .baud_tick (baud_tick_tx),
        .tx_serial (tx),
        .busy      (busy)
    );

    uart_receiver inst3 (
        .clk          (clk),
        .rst          (rst),
        .ready_clear  (ready_clear),
        .baud_tick16x (baud_tick_rx),
        .rx_serial    (rx_serial),
        .ready        (ready),
        .data_out     (rx_data_out)
    );

endmodule