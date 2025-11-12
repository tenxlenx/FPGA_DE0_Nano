# DE0‑Nano LED+KEY template (FuseSoC)

Eight LEDs and both push‑buttons are pre‑wired for the Terasic **DE0‑Nano** (Cyclone IV EP4CE22F17C6N).  
Includes a Quartus QSF constraints fragment with **LED[7:0]**, **KEY[1:0]**, and **CLOCK_50**.

## Build & Program (Quartus backend)

```bash
# From this folder:
fusesoc run --target=quartus de0nano:template:ledkeys:0.2

# Program (adjust .sof path if your edalize build dir differs):
quartus_pgm --mode=jtag -o "p;build/de0nano_template_quartus/top.sof"
```

## Files

- `rtl/top.v` — trivial demo: LEDs blink; LED[0] mirrors KEY0, LED[1] mirrors KEY1 (pressed = lit).
- `constraints/de0nano_pins.qsf` — pin map for LEDs, keys, and clock.
- `de0nano_template.core` — FuseSoC CAPI2 core.
- `.vscode/tasks.json` — convenience tasks for VS Code.

> Notes:
> * The DE0‑Nano push‑buttons are **active‑low**; the example inverts them for readability.
> * If you prefer plain Quartus, create a new project (Cyclone IV E / EP4CE22F17C6N), add `rtl/top.v`,
>   then *Assignments → Import Assignments…* and pick `constraints/de0nano_pins.qsf`.
> * IO standard is set to **3.3‑V LVTTL** for all the user pins.

Enjoy the blinkenlights.
