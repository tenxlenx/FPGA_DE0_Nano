// de0nano_ports.sv - Board I/O wrapper for DE0-Nano.
// Declares all canonical nets and instantiates reusable helper modules.
// Keep this file slim so user logic can focus on the child modules.

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
  inout  wire               I2C_SDAT,    // bidirectional SDIO, actively driven only while writing
  output wire               G_SENSOR_CS_N,
  input  wire               G_SENSOR_INT,

  // ADC128S022 SPI
  output wire               ADC_SCLK,
  input  wire               ADC_SDAT,    // MISO from ADC
  output wire               ADC_SADDR,   // MOSI to ADC
  output wire               ADC_CS_N,

  // Expansion headers (match board capabilities)
  input  wire  [1:0]        GPIO_0_IN,  // GPIO_0_IN[0], GPIO_0_IN[1]
  inout  wire  [33:0]       GPIO_0_IO,  // GPIO_00..GPIO_033
  input  wire  [1:0]        GPIO_1_IN,  // GPIO_1_IN[0], GPIO_1_IN[1]
  inout  wire  [33:0]       GPIO_1_IO   // GPIO_10..GPIO_133
);

  // Buttons are active-low; KEY[0] doubles as a freeze switch for the LED display.
  // KEY[1] is left unused for user experiments.
  wire freeze_display = ~KEY[0];

  // Signed accelerometer samples provided by the ADXL reader.
  wire signed [15:0] accel_x;
  wire signed [15:0] accel_y;

  // ------------------------------------------------------------------------
  // ADXL345 reader and LED mapper
  // ------------------------------------------------------------------------
  // Raw accelerometer samples come from the dedicated reader.
  adxl345_reader #(
    .STARTUP_DELAY  (1_000_000),
    .SAMPLE_INTERVAL(250_000),
    .SPI_DIVIDER    (250)
  ) u_adxl345_reader (
    .clk     (CLOCK_50),
    .freeze  (freeze_display),
    .sclk    (I2C_SCLK),
    .sdat    (I2C_SDAT),
    .cs_n    (G_SENSOR_CS_N),
    .accel_x (accel_x),
    .accel_y (accel_y)
  );

  // Map X/Y samples into the LED bus with adjustable sensitivity.
  tilt_led_mapper #(
    .TILT_SCALE_SHIFT(6)
  ) u_tilt_led_mapper (
    .accel_x(accel_x),
    .accel_y(accel_y),
    .led    (LED)
  );

  // ------------------------------------------------------------------------
  // Default peripheral behaviour
  // ------------------------------------------------------------------------
  assign ADC_SCLK  = 1'b0;
  assign ADC_SADDR = 1'b0;
  assign ADC_CS_N  = 1'b1;

  // Leave the expansion headers undriven until user logic connects.
  assign GPIO_0_IO = {34{1'bz}};
  assign GPIO_1_IO = {34{1'bz}};

  // Prevent unused input warnings.
  wire _unused_gsensor_int = G_SENSOR_INT;
  wire _unused_key1        = KEY[1];

endmodule
