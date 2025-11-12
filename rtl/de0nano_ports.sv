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
  inout  wire               I2C_SDAT,    // bidirectional SDIO
  output wire               G_SENSOR_CS_N,
  input  wire               G_SENSOR_INT,

  // ADC128S022 SPI
  output wire               ADC_SCLK,
  input  wire               ADC_SDAT,    // MISO from ADC
  output wire               ADC_SADDR,   // MOSI to ADC
  output wire               ADC_CS_N,

  // Expansion headers (direction depends on your design; keep as inout for flexibility)
  inout  wire  [35:0]       GPIO_0,
  inout  wire  [35:0]       GPIO_1
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
  assign I2C_SDAT = 1'bz;
  // synthesis translate_on

  // Leave GPIOs floating until assigned in the user design
  // synthesis translate_off
  assign GPIO_0 = {36{1'bz}};
  assign GPIO_1 = {36{1'bz}};
  // synthesis translate_on

endmodule
