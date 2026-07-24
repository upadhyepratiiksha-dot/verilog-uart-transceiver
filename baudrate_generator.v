// 50 MHz clock, 9600 baudrate
// tx = 50MHz/9600 = 5208 cycles to transmit one bit
// rx = 50MHz/(9600*16) = 325 cycles to receive one bit (16x oversampling)

module baudrate_generator (
    input  wire clk,
    input  wire rst,
    output wire tx_enb,
    output wire rx_enb
);

    // counter registers
    reg [12:0] tx_counter; // 13 bits, counts up to 5208
    reg [9:0]  rx_counter; // 10 bits, counts up to 325

    // transmitting counter
    always @(posedge clk or posedge rst) begin
        if (rst)
            tx_counter <= 13'd0;
        else if (tx_counter == 13'd5208)
            tx_counter <= 13'd0;
        else
            tx_counter <= tx_counter + 1'b1;
    end

    // receiving counter (16x oversampling)
    always @(posedge clk or posedge rst) begin
        if (rst)
            rx_counter <= 10'd0;
        else if (rx_counter == 10'd325)
            rx_counter <= 10'd0;
        else
            rx_counter <= rx_counter + 1'b1;
    end

    // enable pulses - high for one clock cycle when counter resets
    assign tx_enb = (tx_counter == 13'd0) ? 1'b1 : 1'b0;
    assign rx_enb = (rx_counter == 10'd0) ? 1'b1 : 1'b0;

endmodule