// tilt_led_mapper.sv - Converts signed accelerometer samples into LED pointers.
// Each axis drives a one-hot nibble, giving an intuitive "bubble level" effect.

module tilt_led_mapper #(
  parameter int unsigned TILT_SCALE_SHIFT = 6
) (
  input  wire signed [15:0] accel_x,
  input  wire signed [15:0] accel_y,
  output wire        [7:0] led
);

  // Convert a signed 16-bit sample into a one-hot pointer across 4 LEDs.
  function automatic [3:0] axis_to_hot(input signed [15:0] sample);
    logic signed [5:0] scaled;
    logic [1:0]        pointer;
    begin
      // Right-shift controls sensitivity; clamp to +/-3 so only 4 bins remain.
      scaled = sample >>> TILT_SCALE_SHIFT;
      if (scaled > 3)   scaled = 3;
      if (scaled < -3)  scaled = -3;

      // Map tilt direction into nibble positions (00 left, 11 right).
      if (scaled >= 2)        pointer = 2'd0;
      else if (scaled >= 0)   pointer = 2'd1;
      else if (scaled <= -2)  pointer = 2'd3;
      else                    pointer = 2'd2;

      axis_to_hot = 4'b0001 << pointer;
    end
  endfunction

  // Concatenate Y (upper nibble) and X (lower nibble) for the full LED bus.
  assign led = {axis_to_hot(accel_y), axis_to_hot(accel_x)};

endmodule
