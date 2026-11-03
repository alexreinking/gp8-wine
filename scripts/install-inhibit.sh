#!/usr/bin/bash
# Install or remove the anti-sleep hook (script + systemd user service).
# Usage: install-inhibit.sh [install|uninstall]
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [ "${1:-install}" = uninstall ]; then
  $SYSTEMCTL disable --now "$SERVICE" || true
  rm -f "$UNITDIR/$SERVICE" "$BINDIR/gp-inhibit.sh"
  $SYSTEMCTL daemon-reload || true
  exit 0
fi

install -D -m 755 "$REPO/gp-inhibit.sh" "$BINDIR/gp-inhibit.sh"
install -d "$UNITDIR"
sed "s|@BINDIR@|$BINDIR|g" "$REPO/$SERVICE.in" > "$UNITDIR/$SERVICE"
$SYSTEMCTL daemon-reload
$SYSTEMCTL enable "$SERVICE"
$SYSTEMCTL restart "$SERVICE"
echo "Installed and started $SERVICE"
