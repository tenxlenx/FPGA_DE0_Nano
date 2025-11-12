# DE0-Nano LED+KEY template (FuseSoC)

Eight LEDs and both push-buttons are pre-wired for the Terasic **DE0-Nano** (Cyclone IV EP4CE22F17C6N).  
Drop-in SystemVerilog resources provide canonical port names plus a reusable QSF include for **LED[7:0]**, **KEY[1:0]**, and **CLOCK_50**.

## First-time setup

```bash
# install python/pipx/FuseSoC prerequisites (supports apt, dnf, pacman, zypper)
./setup_deps.sh
```

> The script installs FuseSoC + Edalize via `pipx` (or via `pip` inside an active Conda env) and checks for the Quartus CLI.  
> Quartus itself still needs to be installed separately from Intel (set `QUARTUS_ROOTDIR` if it's not on `$PATH`).

## Build & Program (Quartus backend)

```bash
# From this folder:
fusesoc run --target=quartus de0nano:template:ledkeys:0.2

# Program (adjust .sof path if your edalize build dir differs):
quartus_pgm --mode=jtag -o "p;build/de0nano_template_quartus/de0nano_ports.sof"
```

## Files

- `rtl/de0nano_board_pkg.sv` — board constants, canonical net names, and helper metadata.
- `rtl/de0nano_ports.sv` — top-level I/O wrapper: declares all DE0-Nano ports and drives a heartbeat/button demo.
- `constraints/de0nano_pins.qsf` — aggregate constraints file; sources the base include and is safe to extend with more peripherals.
- `constraints/de0nano_base_pins.qsf` — reusable include that maps CLOCK_50, KEY[1:0], and LED[7:0] plus sets `timing.sdc`.
- `constraints/de0nano_peripherals_pins.qsf` — optional include that maps the ADXL345 nets, ADC128S022 SPI pins, and both GPIO headers.
- `timing.sdc` — defines the 50 MHz clock and derives PLL clocks/uncertainty.
- `de0nano_template.core` — FuseSoC CAPI2 core.
- `.vscode/tasks.json` — convenience tasks for VS Code.

> Notes:
>
> - The DE0-Nano push-buttons are **active-low**; `de0nano_ports` inverts them for readability.
> - If you prefer plain Quartus, create a new project (Cyclone IV E / EP4CE22F17C6N), add `rtl/de0nano_board_pkg.sv`
>   and `rtl/de0nano_ports.sv`, then *Assignments → Import Assignments…* and pick `constraints/de0nano_pins.qsf`.
>   That file sources `constraints/de0nano_base_pins.qsf` plus `constraints/de0nano_peripherals_pins.qsf`, so you get
>   the base LED/KEY/CLOCK map and (optionally) the accelerometer, ADC, and GPIO header pins straight from the manual.
> - GPIO header pins now mirror the hardware tables: `GPIO_[0|1]_IN[1:0]` are the input-only pads and `GPIO_[0|1]_IO[33:0]`
>   stay bidirectional. The matching QSF comments call out the input-only locations for quick reference.
> - IO standard is set to **3.3-V LVTTL** for all the user pins.

Enjoy the blinkenlights.
