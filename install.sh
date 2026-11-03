#!/usr/bin/bash
# One-step setup for Guitar Pro 8 under Wine (Bottles). Needs only bash and the tools
# in a stock Fedora Kinoite; no make needed. Run with no arguments to do everything.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

# Fail before changing anything if Guitar Pro isn't installed and there is nothing to install it from
preflight_installer() {
  source scripts/common.sh
  [ -f "$GP_EXE" ] && return 0
  shopt -s nullglob
  local candidates=(${INSTALLER:-} ./*.exe)
  [ -f "${candidates[0]:-}" ] && return 0
  echo "error: Guitar Pro is not installed and no installer was found." >&2
  echo "Place the official installer (.exe) next to install.sh, or set INSTALLER=/path/to/setup.exe" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage: ./install.sh [command]

  install            do everything below, in order (default):
                       bottle -> fonts -> Guitar Pro -> icon -> anti-sleep hook
  uninstall          remove the icon and anti-sleep hook (keeps bottle, Guitar Pro, fonts)
  check-deps         report missing tools
  install-bottle     install Bottles if needed and create the bottle
  install-guitar-pro install Guitar Pro from the *.exe in this directory (INSTALLER=...)
  install-icon       install the official icon and update the .desktop file
  install-fonts      ensure the Segoe UI fonts are in the bottle
  install-inhibit    install the anti-sleep hook
  uninstall-icon | uninstall-inhibit
USAGE
}

case "${1:-install}" in
  install)
    scripts/check-deps.sh all
    preflight_installer
    scripts/ensure-bottle.sh
    scripts/install-fonts.sh
    scripts/install-guitar-pro.sh
    scripts/install-icon.sh install
    scripts/install-inhibit.sh install ;;
  uninstall)
    scripts/install-icon.sh uninstall
    scripts/install-inhibit.sh uninstall ;;
  check-deps)        scripts/check-deps.sh all ;;
  install-bottle)    scripts/check-deps.sh bottles; scripts/ensure-bottle.sh ;;
  install-guitar-pro) scripts/check-deps.sh bottles; scripts/install-guitar-pro.sh ;;
  install-icon)      scripts/check-deps.sh icon; scripts/install-icon.sh install ;;
  install-fonts)     scripts/check-deps.sh fonts; scripts/install-fonts.sh ;;
  install-inhibit)   scripts/check-deps.sh inhibit; scripts/install-inhibit.sh install ;;
  uninstall-icon)    scripts/install-icon.sh uninstall ;;
  uninstall-inhibit) scripts/install-inhibit.sh uninstall ;;
  -h|--help|help)    usage ;;
  *) usage >&2; exit 2 ;;
esac
