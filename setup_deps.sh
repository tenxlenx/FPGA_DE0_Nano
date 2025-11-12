#!/usr/bin/env bash
set -Eeuo pipefail

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*"; exit 1; }

PKG_MANAGER=""
SUDO=""

is_conda_env() {
  [[ -n "${CONDA_PREFIX:-}" ]]
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
  else
    warn "No supported package manager detected (apt, dnf, pacman, zypper)."
    PKG_MANAGER=""
  fi
}

ensure_sudo() {
  if (( EUID == 0 )); then
    SUDO=""
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    die "This script needs root privileges to install system packages. Re-run as root or with sudo."
  fi
}

install_system_packages() {
  [[ -n "${PKG_MANAGER}" ]] || return

  ensure_sudo

  case "${PKG_MANAGER}" in
    apt)
      local packages=(git make python3 python3-pip python3-venv pipx)
      info "Installing packages via apt: ${packages[*]}"
      ${SUDO} apt-get update -y
      ${SUDO} apt-get install -y "${packages[@]}"
      ;;
    dnf)
      local packages=(git make python3 python3-pip python3-virtualenv pipx)
      info "Installing packages via dnf: ${packages[*]}"
      ${SUDO} dnf install -y "${packages[@]}"
      ;;
    pacman)
      local packages=(git base-devel python python-pip python-virtualenv pipx)
      info "Installing packages via pacman: ${packages[*]}"
      ${SUDO} pacman -Sy --needed --noconfirm "${packages[@]}"
      ;;
    zypper)
      local packages=(git make python3 python3-pip python3-virtualenv pipx)
      info "Installing packages via zypper: ${packages[*]}"
      ${SUDO} zypper --non-interactive install "${packages[@]}"
      ;;
    *)
      warn "Package manager ${PKG_MANAGER} not handled. Install prerequisites manually."
      ;;
  esac
}

ensure_pipx() {
  if command -v pipx >/dev/null 2>&1; then
    info "pipx already installed."
    pipx ensurepath >/dev/null 2>&1 || true
    hash -r
    return
  fi

  warn "pipx not found; attempting user-level install via pip."
  if command -v python3 >/dev/null 2>&1; then
    python3 -m pip install --user --upgrade pip
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath >/dev/null 2>&1 || true
    hash -r
  else
    die "python3 not available; cannot bootstrap pipx."
  fi

  if ! command -v pipx >/dev/null 2>&1; then
    warn "pipx still missing from PATH. Add ~/.local/bin to PATH and re-run this script."
  fi
}

ensure_fusesoc() {
  if command -v fusesoc >/dev/null 2>&1; then
    info "FuseSoC already installed ($(fusesoc --version 2>/dev/null || echo "version unknown"))."
    return
  fi

  if command -v pipx >/dev/null 2>&1; then
    info "Installing FuseSoC via pipx."
    pipx install --include-deps fusesoc >/dev/null
    hash -r
  else
    warn "pipx missing; falling back to user-level pip install for FuseSoC."
    python3 -m pip install --user --upgrade fusesoc
    hash -r
  fi

  if ! command -v fusesoc >/dev/null 2>&1; then
    warn "FuseSoC not found in PATH even after installation. Ensure ~/.local/bin is exported."
  fi
}

ensure_conda_fusesoc() {
  if ! is_conda_env; then
    return 1
  fi

  local env_name="${CONDA_DEFAULT_ENV:-unknown}"
  info "Conda environment detected (${env_name}) at ${CONDA_PREFIX}"

  local pybin="python"
  if ! command -v "${pybin}" >/dev/null 2>&1; then
    pybin="python3"
  fi
  if ! command -v "${pybin}" >/dev/null 2>&1; then
    die "No python interpreter found in the active conda environment."
  fi

  if ! "${pybin}" -m pip --version >/dev/null 2>&1; then
    warn "pip is missing in this conda environment. Run 'conda install pip' then re-run this script."
    return 1
  fi

  if command -v fusesoc >/dev/null 2>&1; then
    info "FuseSoC already available in this conda environment ($(fusesoc --version 2>/dev/null || echo "version unknown"))."
    return 0
  fi

  info "Installing/Updating FuseSoC inside the conda environment via pip."
  "${pybin}" -m pip install --upgrade pip >/dev/null
  "${pybin}" -m pip install --upgrade fusesoc >/dev/null
  hash -r

  if command -v fusesoc >/dev/null 2>&1; then
    info "FuseSoC installed inside conda environment."
  else
    warn "FuseSoC installation via conda env pip did not expose the CLI on PATH."
  fi
}

check_quartus() {
  if command -v quartus_sh >/dev/null 2>&1; then
    info "Quartus CLI detected: $(quartus_sh --version 2>/dev/null | head -n1 || echo "version unknown")."
  else
    warn "Quartus Prime CLI (quartus_sh) not found. Install Intel Quartus Prime Lite/Standard and export QUARTUS_ROOTDIR."
  fi
}

main() {
  info "Detecting package manager and installing base dependencies (python3, pipx, make, git)."
  detect_pkg_manager
  install_system_packages

  if is_conda_env; then
    ensure_conda_fusesoc
  else
    info "Ensuring pipx is available."
    ensure_pipx
    info "Ensuring FuseSoC (and Edalize) are installed."
    ensure_fusesoc
  fi

  check_quartus

  cat <<'EOF'

Dependencies check completed.
If PATH changes were applied (pipx/pip), open a new shell or source the relevant profile.
Remember to install Intel Quartus manually if it's not already present.
EOF
}

main "$@"
