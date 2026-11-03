#!/usr/bin/bash
# Install Guitar Pro 8 into a Bottles bottle from a locally supplied installer.
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [ -f "$GP_EXE" ]; then
  echo "Guitar Pro is already installed in bottle '$BOTTLE_NAME'"
  exit 0
fi

installer=${INSTALLER:-}
if [ -z "$installer" ]; then
  shopt -s nullglob
  candidates=("$REPO"/*.exe)
  [ ${#candidates[@]} -gt 0 ] && installer=${candidates[0]}
fi
if [ ! -f "$installer" ]; then
  echo "error: Guitar Pro is not installed and no installer was found." >&2
  echo "Place the official installer (.exe) next to install.sh, or set INSTALLER=/path/to/setup.exe" >&2
  exit 1
fi

"$(dirname "$0")/ensure-bottle.sh"

# The Bottles flatpak can't see the repo directory, so stage the installer inside the bottle.
staged="$BOTTLE_DIR/drive_c/windows/temp/gp8-setup.exe"
mkdir -p "$(dirname "$staged")"
trap 'rm -f "$staged"' EXIT
cp "$installer" "$staged"

echo "Running $(basename "$installer") silently (this can take a while)"
$BOTTLES_CLI run -b "$BOTTLE_NAME" -e "$staged" -- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

if [ ! -f "$GP_EXE" ]; then
  echo "error: installer finished but '$GP_EXE' does not exist" >&2
  exit 1
fi
# The installer launches Guitar Pro when it finishes; close that window and flush the prefix.
stop_bottle
echo "Installed Guitar Pro"
