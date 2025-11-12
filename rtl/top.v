// top.v — Minimal DE0‑Nano template
// Wires all 8 LEDs and both push-buttons, plus the 50 MHz clock.
// KEY inputs on the board are active-low. We invert them to get active-high presses.
//
// Ports:
//   CLOCK_50 : 50 MHz onboard clock (PIN_R8)
//   KEY      : Two push-buttons, KEY[0] (PIN_J15), KEY[1] (PIN_E1), active-low
//   LED      : Eight user LEDs LED[7:0]
//
module top (
    input  wire       CLOCK_50,
    input  wire [1:0] KEY,
    output wire [7:0] LED
);
    // Debounce-free demo: simply invert KEY to make "pressed == 1".
    // For real designs, add a synchronizer + debounce filter.
    wire [1:0] key_pressed = ~KEY;

    // Slow counter for visible LED activity
    reg [27:0] ctr = 28'd0;
    always @(posedge CLOCK_50) begin
        ctr <= ctr + 1'b1;
    end

    // Demo wiring:
    // - LED[1:0] mirror the two buttons (pressed = 1 lights LED)
    // - LED[7:2] show a slow-moving binary pattern from the counter
    assign LED[0] = key_pressed[0];
    assign LED[1] = key_pressed[1];
    assign LED[2] = ctr[25];
    assign LED[3] = ctr[24];
    assign LED[4] = ctr[23];
    assign LED[5] = ctr[22];
    assign LED[6] = ctr[21];
    assign LED[7] = ctr[20];

endmodule
