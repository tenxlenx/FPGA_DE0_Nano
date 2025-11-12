// adxl345_reader.sv - Self-contained 3-wire SPI reader for the DE0-Nano accelerometer.

module adxl345_reader #(
  parameter int unsigned STARTUP_DELAY   = 1_000_000, // 20 ms at 50 MHz
  parameter int unsigned SAMPLE_INTERVAL =   250_000, // 5  ms at 50 MHz
  parameter int unsigned SPI_DIVIDER     =       250  // 100 kHz SCLK (mode 3)
) (
  input  wire               clk,
  input  wire               freeze,
  output wire               sclk,
  inout  wire               sdat,
  output wire               cs_n,
  output logic signed [15:0] accel_x,
  output logic signed [15:0] accel_y
);

  // ------------------------------------------------------------------------
  // ADXL345 register definitions
  // ------------------------------------------------------------------------
  localparam logic [7:0] REG_POWER_CTL   = 8'h2D;
  localparam logic [7:0] REG_DATA_FORMAT = 8'h31;
  localparam logic [7:0] CMD_MEASURE     = 8'h08;
  localparam logic [7:0] CMD_FORMAT_FULL = 8'h48;  // enable full-res + 3-wire SPI
  localparam logic [7:0] CMD_READ_DATAX0 = 8'hF2;  // read | multibyte | DATAX0

  // ------------------------------------------------------------------------
  // Power-on reset
  // ------------------------------------------------------------------------
  logic [15:0] por_counter = 16'd0;
  wire         rst         = ~por_counter[15];

  always_ff @(posedge clk) begin
    if (rst) por_counter <= por_counter + 16'd1;
  end

  // ------------------------------------------------------------------------
  // Shared SPI wiring (3-wire: MOSI/MISO share SDIO line)
  // ------------------------------------------------------------------------
  logic        spi_start;
  logic [7:0]  spi_tx_data;
  logic        spi_tx_drive;
  logic        spi_active;
  logic [2:0]  spi_bit_index;
  logic [7:0]  spi_shift;
  logic [7:0]  spi_rx_shift;
  logic [7:0]  spi_rx_byte;
  logic        spi_byte_done;
  logic        spi_drive;
  logic [15:0] spi_divider_cnt = 16'd0;
  logic        spi_tick        = 1'b0;
  logic        tx_pending;
  logic        sdio_drive;
  logic        sdio_out;
  logic        spi_sclk_reg;
  logic        g_sensor_cs_n_reg;

  wire spi_idle    = ~spi_active && ~tx_pending;
  wire [7:0] spi_rx_next = {spi_rx_shift[6:0], sdat};

  assign sclk = spi_sclk_reg;
  assign cs_n = g_sensor_cs_n_reg;
  assign sdat = sdio_drive ? sdio_out : 1'bz;

  // Clock divider for the SPI engine
  always_ff @(posedge clk) begin
    if (rst) begin
      spi_divider_cnt <= 16'd0;
      spi_tick        <= 1'b0;
    end else if (spi_divider_cnt == SPI_DIVIDER - 1) begin
      spi_divider_cnt <= 16'd0;
      spi_tick        <= 1'b1;
    end else begin
      spi_divider_cnt <= spi_divider_cnt + 16'd1;
      spi_tick        <= 1'b0;
    end
  end

  // Track active transactions to prevent double launches
  always_ff @(posedge clk) begin
    if (rst) begin
      tx_pending <= 1'b0;
    end else begin
      if (spi_start)          tx_pending <= 1'b1;
      else if (spi_byte_done) tx_pending <= 1'b0;
    end
  end

  // Serial shifter (SPI mode 3)
  always_ff @(posedge clk) begin
    if (rst) begin
      spi_active    <= 1'b0;
      spi_bit_index <= 3'd0;
      spi_shift     <= 8'd0;
      spi_rx_shift  <= 8'd0;
      spi_rx_byte   <= 8'd0;
      spi_drive     <= 1'b0;
      spi_byte_done <= 1'b0;
      spi_sclk_reg  <= 1'b1;
      sdio_drive    <= 1'b0;
      sdio_out      <= 1'b0;
    end else begin
      spi_byte_done <= 1'b0;

      if (spi_start && ~spi_active) begin
        spi_active    <= 1'b1;
        spi_bit_index <= 3'd7;
        spi_shift     <= spi_tx_data;
        spi_drive     <= spi_tx_drive;
        spi_rx_shift  <= 8'd0;
        spi_sclk_reg  <= 1'b1;
        sdio_drive    <= spi_tx_drive;
        if (spi_tx_drive) sdio_out <= spi_tx_data[7];
      end else if (spi_active && spi_tick) begin
        if (spi_sclk_reg) begin
          spi_sclk_reg <= 1'b0;
          if (spi_drive) sdio_out <= spi_shift[spi_bit_index];
        end else begin
          spi_sclk_reg <= 1'b1;
          spi_rx_shift <= spi_rx_next;
          if (spi_bit_index == 3'd0) begin
            spi_active    <= 1'b0;
            spi_byte_done <= 1'b1;
            spi_rx_byte   <= spi_rx_next;
            sdio_drive    <= 1'b0;
          end else begin
            spi_bit_index <= spi_bit_index - 3'd1;
          end
        end
      end
    end
  end

  // ------------------------------------------------------------------------
  // High-level accelerometer transaction controller
  // ------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ST_BOOT_DELAY     = 4'd0,
    ST_WRITE_PWR_CMD  = 4'd1,
    ST_WRITE_PWR_DATA = 4'd2,
    ST_WRITE_FMT_CMD  = 4'd3,
    ST_WRITE_FMT_DATA = 4'd4,
    ST_IDLE           = 4'd5,
    ST_READ_CMD       = 4'd6,
    ST_READ_X0        = 4'd7,
    ST_READ_X1        = 4'd8,
    ST_READ_Y0        = 4'd9,
    ST_READ_Y1        = 4'd10,
    ST_READ_Z0        = 4'd11,
    ST_READ_Z1        = 4'd12,
    ST_UPDATE         = 4'd13
  } accel_state_t;

  accel_state_t accel_state;

  logic [19:0] startup_counter;
  logic [19:0] sample_counter;
  logic [7:0]  x_lsb, x_msb;
  logic [7:0]  y_lsb, y_msb;
  logic [7:0]  z_lsb, z_msb;

  always_ff @(posedge clk) begin
    if (rst) begin
      accel_state       <= ST_BOOT_DELAY;
      startup_counter   <= 20'd0;
      sample_counter    <= 20'd0;
      x_lsb             <= 8'd0;
      x_msb             <= 8'd0;
      y_lsb             <= 8'd0;
      y_msb             <= 8'd0;
      z_lsb             <= 8'd0;
      z_msb             <= 8'd0;
      accel_x           <= 16'sd0;
      accel_y           <= 16'sd0;
      spi_start         <= 1'b0;
      spi_tx_data       <= 8'd0;
      spi_tx_drive      <= 1'b0;
      g_sensor_cs_n_reg <= 1'b1;
    end else begin
      spi_start <= 1'b0;

      case (accel_state)
        ST_BOOT_DELAY: begin
          g_sensor_cs_n_reg <= 1'b1;
          if (startup_counter < STARTUP_DELAY) begin
            startup_counter <= startup_counter + 20'd1;
          end else begin
            accel_state <= ST_WRITE_PWR_CMD;
          end
        end

        ST_WRITE_PWR_CMD: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            accel_state <= ST_WRITE_PWR_DATA;
          end else if (spi_idle) begin
            spi_tx_data  <= REG_POWER_CTL;
            spi_tx_drive <= 1'b1;
            spi_start    <= 1'b1;
          end
        end

        ST_WRITE_PWR_DATA: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            g_sensor_cs_n_reg <= 1'b1;
            accel_state       <= ST_WRITE_FMT_CMD;
          end else if (spi_idle) begin
            spi_tx_data  <= CMD_MEASURE;
            spi_tx_drive <= 1'b1;
            spi_start    <= 1'b1;
          end
        end

        ST_WRITE_FMT_CMD: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            accel_state <= ST_WRITE_FMT_DATA;
          end else if (spi_idle) begin
            spi_tx_data  <= REG_DATA_FORMAT;
            spi_tx_drive <= 1'b1;
            spi_start    <= 1'b1;
          end
        end

        ST_WRITE_FMT_DATA: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            g_sensor_cs_n_reg <= 1'b1;
            sample_counter    <= SAMPLE_INTERVAL;
            accel_state       <= ST_IDLE;
          end else if (spi_idle) begin
            spi_tx_data  <= CMD_FORMAT_FULL;
            spi_tx_drive <= 1'b1;
            spi_start    <= 1'b1;
          end
        end

        ST_IDLE: begin
          g_sensor_cs_n_reg <= 1'b1;
          if (sample_counter != 20'd0) begin
            sample_counter <= sample_counter - 20'd1;
          end else begin
            accel_state <= ST_READ_CMD;
          end
        end

        ST_READ_CMD: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            accel_state <= ST_READ_X0;
          end else if (spi_idle) begin
            spi_tx_data  <= CMD_READ_DATAX0;
            spi_tx_drive <= 1'b1;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_X0: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            x_lsb       <= spi_rx_byte;
            accel_state <= ST_READ_X1;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_X1: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            x_msb       <= spi_rx_byte;
            accel_state <= ST_READ_Y0;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_Y0: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            y_lsb       <= spi_rx_byte;
            accel_state <= ST_READ_Y1;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_Y1: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            y_msb       <= spi_rx_byte;
            accel_state <= ST_READ_Z0;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_Z0: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            z_lsb       <= spi_rx_byte;
            accel_state <= ST_READ_Z1;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_READ_Z1: begin
          g_sensor_cs_n_reg <= 1'b0;
          if (spi_byte_done) begin
            z_msb             <= spi_rx_byte;
            g_sensor_cs_n_reg <= 1'b1;
            accel_state       <= ST_UPDATE;
          end else if (spi_idle) begin
            spi_tx_data  <= 8'h00;
            spi_tx_drive <= 1'b0;
            spi_start    <= 1'b1;
          end
        end

        ST_UPDATE: begin
          g_sensor_cs_n_reg <= 1'b1;
          sample_counter    <= SAMPLE_INTERVAL;
          if (!freeze) begin
            accel_x <= {x_msb, x_lsb};
            accel_y <= {y_msb, y_lsb};
          end
          accel_state <= ST_IDLE;
        end

        default: accel_state <= ST_BOOT_DELAY;
      endcase
    end
  end

endmodule
