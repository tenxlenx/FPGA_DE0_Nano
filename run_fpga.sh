#!/usr/bin/env bash
set -Eeuo pipefail

CORE="de0nano:template:ledkeys:0.2"
CORES_ROOT="."

info(){ echo -e "\033[1;34m[i]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[!]\033[0m $*"; }
die(){ echo -e "\033[1;31m[x]\033[0m $*"; exit 1; }

# Ensure Quartus CLI is reachable
if ! command -v quartus_sh >/dev/null 2>&1; then
  if [[ -n "${QUARTUS_ROOTDIR:-}" && -x "${QUARTUS_ROOTDIR}/bin/quartus_sh" ]]; then
    export PATH="${QUARTUS_ROOTDIR}/bin:$PATH"
  else
    die "quartus_sh not found. Set QUARTUS_ROOTDIR or add Quartus bin to PATH."
  fi
fi

# Build: prefer FuseSoC if a .core is present, else plain Quartus
if command -v fusesoc >/dev/null 2>&1 && compgen -G "*.core" >/dev/null; then
  info "Building via FuseSoC (core: ${CORE})"
  fusesoc --cores-root "${CORES_ROOT}" run --target=quartus "${CORE}"
else
  QPF=$(ls -1 *.qpf 2>/dev/null | head -n1 || true)
  [[ -n "${QPF}" ]] || die "No FuseSoC core and no .qpf found. Put a .core here or a Quartus project."
  PROJ="${QPF%.qpf}"
  info "Building via Quartus CLI (project: ${PROJ})"
  quartus_sh --flow compile "${PROJ}"
fi

# Locate the .sof
SOF=$(find build -type f -name '*.sof' -print -quit 2>/dev/null || true)
if [[ -z "${SOF}" ]]; then
  SOF=$(find . -maxdepth 2 -path './output_files/*.sof' -print -quit 2>/dev/null || true)
fi
[[ -n "${SOF}" ]] || die "No .sof produced. Check build logs."

# Program over JTAG
if command -v jtagd >/dev/null 2>&1; then
  jtagd --user-start || true
fi
info "Available JTAG cables:"
quartus_pgm -l || true

info "Programming ${SOF}"
quartus_pgm --mode=jtag -o "p;${SOF}@1"
info "Done."

