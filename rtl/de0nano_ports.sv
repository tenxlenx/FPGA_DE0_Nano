// de0nano_ports.sv - Board I/O wrapper for DE0-Nano.
// Declare all common nets once and keep your core logic in a child module for reuse.

import de0nano_board_pkg::*;

module de0nano_ports
(
  // Clocks
  input  wire               CLOCK_50,

  // User I/O
  input  wire  [1:0]        KEY,         // active-low on PCB
  output wire  [7:0]        LED,

  // ADXL345 3-wire SPI plus INT
  output wire               I2C_SCLK,    // SPI SCLK (shared label on PCB silk)
  input  wire               I2C_SDAT,    // bidirectional SDIO (treated as input here to match board pin capabilities)
  output wire               G_SENSOR_CS_N,
  input  wire               G_SENSOR_INT,

  // ADC128S022 SPI
  output wire               ADC_SCLK,
  input  wire               ADC_SDAT,    // MISO from ADC
  output wire               ADC_SADDR,   // MOSI to ADC
  output wire               ADC_CS_N,

  // Expansion headers (match board capabilities: two input-only pins + 34 bidirectional per header)
  input  wire  [1:0]        GPIO_0_IN,  // GPIO_0_IN[0], GPIO_0_IN[1]
  inout  wire  [33:0]       GPIO_0_IO,  // GPIO_00..GPIO_033
  input  wire  [1:0]        GPIO_1_IN,  // GPIO_1_IN[0], GPIO_1_IN[1]
  inout  wire  [33:0]       GPIO_1_IO   // GPIO_10..GPIO_133
);

  // --------------------------------------------------------------------------
  // Example: minimal heartbeat plus button mirror (replace with your design)
  // --------------------------------------------------------------------------
  reg [25:0] hb = 26'd0;
  always @(posedge CLOCK_50) hb <= hb + 1'b1;

  // Buttons are active-low; invert for logic 1 when pressed
  wire [1:0] key_pressed = ~KEY;

  // Demo LEDs: [1:0] mirror buttons, [7:2] show a slow counter
  assign LED[1:0] = key_pressed;
  assign LED[2]   = hb[24];
  assign LED[3]   = hb[23];
  assign LED[4]   = hb[22];
  assign LED[5]   = hb[21];
  assign LED[6]   = hb[20];
  assign LED[7]   = hb[19];

  // Stub peripherals (tie off until real logic is connected)
  assign I2C_SCLK      = 1'b1;   // idle high for SPI mode 3
  assign G_SENSOR_CS_N = 1'b1;   // inactive
  assign ADC_SCLK      = 1'b0;
  assign ADC_SADDR     = 1'b0;
  assign ADC_CS_N      = 1'b1;

  // Tri-state the bidirectional SDIO by default
  // synthesis translate_off
  // kept as a no-op during simulation/build since the pin is treated as input in the top-level
  // synthesis translate_on

  // Leave GPIO headers undriven until user logic connects
  // synthesis translate_off
  // Intentional high-Z: consult the board manual for the input-only pins listed above
  // synthesis translate_on

  // Default the bidirectional headers to high-Z so user logic can safely override
  assign GPIO_0_IO = {34{1'bz}};
  assign GPIO_1_IO = {34{1'bz}};

endmodule
