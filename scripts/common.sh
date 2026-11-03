# Shared settings, sourced by the install scripts. Override via the environment.
BOTTLE_NAME=${BOTTLE_NAME:-Guitar Pro}
BOTTLES_CLI=${BOTTLES_CLI:-flatpak run --command=bottles-cli com.usebottles.bottles}
BOTTLES_DATA=${BOTTLES_DATA:-$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles}
BOTTLE_DIR=${BOTTLE_DIR:-$BOTTLES_DATA/${BOTTLE_NAME// /-}}
GP_EXE=${GP_EXE:-$BOTTLE_DIR/drive_c/Program Files/Arobas Music/Guitar Pro 8/GuitarPro.exe}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
ICON_NAME=guitar-pro-8

# X11 window class the desktop uses to tie the running window to its .desktop file.
# Proton-based runners (Soda, GE, ...) report "steam_proton"; plain Wine uses the exe name.
runner=$(sed -n 's/^Runner: *//p' "$BOTTLE_DIR/bottle.yml" 2>/dev/null || true)
case $runner in
  soda*|*proton*|*umu*) wm_class=steam_proton ;;
  *)                    wm_class=guitarpro.exe ;;
esac
GP_WM_CLASS=${GP_WM_CLASS:-$wm_class}
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Anti-sleep hook install locations
PREFIX=${PREFIX:-$HOME/.local}
BINDIR=${BINDIR:-$PREFIX/bin}
UNITDIR=${UNITDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}
SYSTEMCTL=${SYSTEMCTL:-systemctl --user}
SERVICE=gp-inhibit.service

# Best-effort stop of the bottle's Wine processes. `bottles-cli stop` alone can hang forever
# waiting on a Guitar Pro that doesn't exit, so close that first and cap the rest.
stop_bottle() {
  pkill -f 'GuitarPro\.exe' 2>/dev/null || true
  timeout 30 $BOTTLES_CLI stop -b "$BOTTLE_NAME" > /dev/null 2>&1 || true
}
