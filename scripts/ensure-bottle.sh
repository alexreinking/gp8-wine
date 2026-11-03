#!/usr/bin/bash
# Make sure Bottles is installed and the bottle exists (a fresh prefix, no Guitar Pro yet).
set -euo pipefail
source "$(dirname "$0")/common.sh"

# Fetch Bottles from Flathub if it isn't there (only when using the default flatpak CLI)
if [[ $BOTTLES_CLI == flatpak* ]] && ! flatpak info com.usebottles.bottles >/dev/null 2>&1; then
  echo "Installing Bottles from Flathub"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub com.usebottles.bottles
fi

if [ ! -f "$BOTTLE_DIR/bottle.yml" ]; then
  echo "Creating bottle '$BOTTLE_NAME'"
  if ! $BOTTLES_CLI new --bottle-name "$BOTTLE_NAME" --environment application --arch win64; then
    # Bottles also installs a few optional dependencies (e.g. the Courier New font) and reports
    # failure if a download hiccups. Carry on if the bottle itself came out usable: its runner is there.
    runner=$(sed -n 's/^Runner: *//p' "$BOTTLE_DIR/bottle.yml" 2>/dev/null || true)
    if [ -n "$runner" ] && [ -d "$BOTTLES_DATA/../runners/$runner" ]; then
      echo "warning: Bottles reported errors creating '$BOTTLE_NAME' (an optional dependency, probably a failed download); continuing" >&2
    else
      echo "error: could not create bottle '$BOTTLE_NAME'" >&2
      exit 1
    fi
  fi
fi
