# DE0-Nano LED+KEY Template (FuseSoC)

Reusable SystemVerilog, pin constraints, and tooling glue for the Terasic **DE0-Nano** (Cyclone IV EP4CE22F17C6N).  
The default design bit-bangs the on-board ADXL345 accelerometer over three-wire SPI and visualises board tilt on the eight user LEDs, while both push-buttons remain accessible for user interaction.

---

## Contents at a Glance
- `rtl/de0nano_ports.sv` — canonical top-level I/O wrapper that instantiates the helper modules and houses the board ports.
- `rtl/adxl345_reader.sv` — reusable 3-wire SPI controller/state machine for the on-board ADXL345 (freeze-aware).
- `rtl/tilt_led_mapper.sv` — parameterised mapper that turns signed samples into LED pointers.
- `rtl/de0nano_board_pkg.sv` — board metadata (clock rate, widths, pin-name constants) for reuse across projects.
- `constraints/*.qsf` — modular Quartus settings: base LED/KEY/CLOCK pins plus peripherals (ADXL, ADC128S022, GPIO headers).
- `timing.sdc` — 50 MHz clock definition for TimeQuest.
- `de0nano_template.core` — FuseSoC (CAPI2) core that targets Quartus.
- `run_fpga.sh` — helper script that builds via FuseSoC/Quartus and flashes with `quartus_pgm`.
- `setup_deps.sh` — cross-distro script that installs git/make/python/pipx and FuseSoC/Edalize.

---

## Requirements

### Hardware
- Terasic DE0-Nano development kit.
- USB-Blaster connection (on-board or external) with JTAG access to the FPGA.

### Software
| Component | Suggested Version | Notes |
|-----------|------------------|-------|
| Quartus Prime Lite/Standard | 18.1 or newer | Must provide `quartus_sh`, `quartus_cdb`, `quartus_pgm`, and `jtagd`. Set `QUARTUS_ROOTDIR` when not on `PATH`. |
| FuseSoC + Edalize | 2.x | Installed by `setup_deps.sh` via `pipx` or active Conda `pip`. |
| Python | 3.8+ | Required by FuseSoC tooling. |
| git, make, pkg manager | — | Used when generating the Quartus project and pulling dependencies. |
| `sudo` (optional) | — | Only needed if you let the setup script install packages system-wide. |

---

## Quick Start
1. **Clone or copy** this repository on a machine that can reach the board via USB.
2. *(Optional)* **Activate Conda** to isolate Python packages:
   ```bash
   source ~/miniconda3/etc/profile.d/conda.sh
   conda activate base
   ```
3. **Install prerequisites** (git, make, python, pipx, FuseSoC, Edalize):
   ```bash
   ./setup_deps.sh
   ```
   - Supports `apt`, `dnf`, `pacman`, and `zypper`. The script prompts for `sudo`.
   - If `pipx` is unavailable inside an active Conda env, it falls back to `pip install --user`.
4. **Install Quartus Prime** from Intel (not bundled here). Point the environment at your installation:
   ```bash
   export QUARTUS_ROOTDIR=/path/to/intelFPGA_lite/25.1/quartus
   export PATH="$QUARTUS_ROOTDIR/bin:$PATH"
   ```
5. **Connect the USB-Blaster** and verify it shows up:
   ```bash
   jtagconfig
   ```

At this stage you can build/program either with the helper script or manually.

---

## Build & Program

### One-command Flow
```bash
QUARTUS_ROOTDIR=/path/to/quartus ./run_fpga.sh
```
The script:
1. Verifies `quartus_sh` is reachable (using `QUARTUS_ROOTDIR` if exported).
2. Runs `fusesoc --cores-root . run --target=quartus de0nano:template:ledkeys:0.2`.
3. Finds the generated `.sof` (usually under `build/de0nano_template_ledkeys_0.2/quartus-quartus/`).
4. Starts `jtagd` on demand and prints available USB-Blaster cables.
5. Calls `quartus_pgm --mode=jtag -o "p;<sof>@1"` to configure the FPGA.

### Manual FuseSoC / Quartus CLI
```bash
# Build the Quartus project
fusesoc run --target=quartus de0nano:template:ledkeys:0.2

# Program (adjust the .sof path if your edalize build dir differs)
quartus_pgm --mode=jtag \
  -o "p;build/de0nano_template_ledkeys_0.2/quartus-quartus/de0nano_template_ledkeys_0_2.sof@1"
```

### Pure Quartus Project
1. Create a Quartus project targeting **Cyclone IV E / EP4CE22F17C6N**.
2. Add `rtl/de0nano_board_pkg.sv` and `rtl/de0nano_ports.sv`.
3. Import `constraints/de0nano_pins.qsf` (*Assignments → Import Assignments…*). It includes the base LED/KEY/CLOCK map plus the optional peripheral/GPIO file.
4. Add `timing.sdc` under *Assignments → TimeQuest Timing Analyzer Settings*.
5. Compile and program with your usual flow.

---

## Demo Behavior
- **Tilt visualiser**: The ADXL345 is configured for full-resolution ±2 g mode with 3-wire SPI enabled (`CMD_FORMAT_FULL = 0x48`). `LED[3:0]` display the X axis, `LED[7:4]` display Y.
- **Sensitivity**: The mapping uses `TILT_SCALE_SHIFT` (default `6`) to divide the signed 16-bit readings, so each LED step represents roughly 1.2° of tilt. Lower the shift for more sensitivity or raise it to add hysteresis.
- **Freeze**: Holding **KEY0** (active-low) freezes the last sampled X/Y pair, letting you steady the board before releasing.
- **KEY1**: Currently unused and left exposed in `de0nano_ports` for user experiments.
- **ADC & GPIO**: The ADC128S022 SPI interface is brought out but held inactive; GPIO headers are left high-Z until user logic consumes them.

Feel free to swap the LED logic with your own module—the ADXL samples (`accel_x`, `accel_y`) are available near the bottom of `de0nano_ports.sv`.

---

## File Reference

| Path | Purpose |
|------|---------|
| `rtl/de0nano_board_pkg.sv` | Board-specific constants, strings, and widths. |
| `rtl/de0nano_ports.sv` | Top-level ports plus instantiations of the helper modules. |
| `rtl/adxl345_reader.sv` | Standalone 3-wire SPI state machine that streams ADXL samples and honors the freeze switch. |
| `rtl/tilt_led_mapper.sv` | Converts signed X/Y acceleration samples into LED pointers with adjustable sensitivity. |
| `constraints/de0nano_base_pins.qsf` | Pins for `CLOCK_50`, `KEY[1:0]`, `LED[7:0]` + IO standards and `timing.sdc`. |
| `constraints/de0nano_peripherals_pins.qsf` | ADXL, ADC, and GPIO header pin assignments/standards. |
| `constraints/de0nano_pins.qsf` | Aggregates the base + peripheral QSF files. |
| `timing.sdc` | Defines the 50 MHz oscillator and derived clocks. |
| `de0nano_template.core` | FuseSoC target definition (Quartus backend, ledkeys demo). |
| `run_fpga.sh` | Build + program helper. |
| `setup_deps.sh` | Dependency bootstrapper for Python tooling. |

---

## Troubleshooting
- **`quartus_sh not found`**: Export `QUARTUS_ROOTDIR` or add `<quartus>/bin` to `PATH`. The helper script stops early if it cannot locate the executable.
- **`sudo: a terminal is required` during `setup_deps.sh`**: Run the script from an interactive shell so `sudo` can prompt, or pre-install `git make python3 python3-pip python3-venv pipx`.
- **`No .sof produced`**: Inspect the logs under `build/de0nano_template_ledkeys_0.2`. Ensure the Quartus version matches the board device and that licensing allows compilation.
- **USB-Blaster missing**: Run `jtagconfig` or `quartus_pgm -l` to confirm permissions. (On Linux, install the Intel USB rules or start `jtagd --user-start`.)
- **LEDs frozen**: Confirm KEY0 isn’t held down (freeze mode). If they never update, verify the ADXL ribbon cable and recompile after editing `rtl/de0nano_ports.sv`.

Enjoy the blinkenlights!
