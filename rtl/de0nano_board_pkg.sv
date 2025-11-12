// de0nano_board_pkg.sv - Canonical names and constants for Terasic DE0-Nano (Cyclone IV EP4CE22F17C6N)
package de0nano_board_pkg;
  // Human and logic info
  localparam string BOARD_NAME      = "Terasic DE0-Nano";
  localparam string FPGA_DEVICE     = "EP4CE22F17C6";
  localparam string FPGA_FAMILY     = "Cyclone IV E";
  localparam int    CLOCK_50_HZ     = 50_000_000;

  // On-board user I/O
  localparam int LED_COUNT          = 8;   // LED[7:0]
  localparam int KEY_COUNT          = 2;   // KEY[1:0], active-low on the PCB

  // On-board sensors and peripherals
  // ADXL345 (3-wire SPI on the "I2C" nets plus chip select and interrupt)
  localparam bit   ADXL345_PRESENT   = 1;
  localparam bit   ADXL345_SPI_MODE3 = 1;

  // ADC128S022 (8-channel 12-bit SPI ADC)
  localparam bit   ADC128S022_PRESENT = 1;
  localparam int   ADC_CHANNELS        = 8;

  // GPIO headers (exposed edge connectors). Widths are conventional; pin mapping is done in QSF.
  localparam int GPIO0_WIDTH        = 36;  // GPIO_0[35:0]
  localparam int GPIO1_WIDTH        = 36;  // GPIO_1[35:0]

  // Canonical logical port names to use at the top level (referenced by QSF)
  localparam string PIN_CLOCK_50     = "CLOCK_50";
  localparam string PIN_LED_BUS      = "LED";            // [7:0]
  localparam string PIN_KEY_BUS      = "KEY";            // [1:0], active-low

  // ADXL345 lines (3-wire SPI)
  localparam string PIN_I2C_SCLK     = "I2C_SCLK";       // shared SCLK
  localparam string PIN_I2C_SDAT     = "I2C_SDAT";       // shared SDIO (bidirectional)
  localparam string PIN_GSENS_CS_N   = "G_SENSOR_CS_N";  // chip select
  localparam string PIN_GSENS_INT    = "G_SENSOR_INT";   // interrupt

  // ADC128S022 lines
  localparam string PIN_ADC_SCLK     = "ADC_SCLK";
  localparam string PIN_ADC_SDAT     = "ADC_SDAT";       // MISO from ADC to FPGA
  localparam string PIN_ADC_SADDR    = "ADC_SADDR";      // MOSI to ADC
  localparam string PIN_ADC_CS_N     = "ADC_CS_N";       // chip select

  // GPIO headers
  localparam string PIN_GPIO0_BUS    = "GPIO_0";         // [35:0]
  localparam string PIN_GPIO1_BUS    = "GPIO_1";         // [35:0]
endpackage
