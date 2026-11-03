#!/usr/bin/bash
# Extract the official icon from GuitarPro.exe, install it into the user icon theme,
# and point the Bottles-generated .desktop file at it (or create one if none exists).
# Usage: install-icon.sh [install|uninstall]
set -euo pipefail
source "$(dirname "$0")/common.sh"

apps=$DATA_HOME/applications
icons=$DATA_HOME/icons/hicolor
images=$REPO/build/images
bottles_icon=$BOTTLE_DIR/icons/GuitarPro.png
marker="X-GP8-Wine-Generated=true"

# NUL-separated .desktop files that Bottles generated for this bottle's Guitar Pro
bottles_desktop_files() {
  local f
  for f in "$apps"/*.desktop; do
    [ -f "$f" ] || continue
    grep -qF "$marker" "$f" && continue
    if grep -qF "bottles-cli" "$f" && grep -qF -- "-b '$BOTTLE_NAME'" "$f"; then printf '%s\0' "$f"; fi
  done
}

refresh() {
  # A GTK icon cache here is optional and hides icons newer than itself, so don't keep one.
  rm -f "$icons/icon-theme.cache"
  update-desktop-database -q "$apps" 2>/dev/null || true
  # Running KDE processes only list icon directories that existed when they started
  # (e.g. a first-time hicolor/512x512/apps); this tells them to rescan.
  gdbus emit --session --object-path /KIconLoader --signal org.kde.KIconLoader.iconChanged 0 \
    >/dev/null 2>&1 || true
}

uninstall() {
  find "$icons" -path '*/apps/'"$ICON_NAME.png" -delete 2>/dev/null || true
  grep -lsZF "$marker" "$apps"/*.desktop 2>/dev/null | xargs -0 -r rm -f || true
  # Hand Bottles' own icon back to its desktop file
  if [ -f "$bottles_icon" ]; then
    bottles_desktop_files | xargs -0 -r sed -i "s|^Icon=$ICON_NAME\$|Icon=$bottles_icon|"
  fi
  bottles_desktop_files | xargs -0 -r sed -i "s|^StartupWMClass=$GP_WM_CLASS\$|StartupWMClass=GuitarPro|"
  refresh
}

if [ "${1:-install}" = uninstall ]; then uninstall; exit 0; fi

if [ ! -f "$GP_EXE" ]; then
  echo "error: '$GP_EXE' not found; install Guitar Pro first" >&2
  exit 1
fi

# Re-extract only when the executable is newer than what we extracted
if [ ! -d "$images" ] || [ "$GP_EXE" -nt "$images" ]; then
  rm -rf "$images"
  python3 -I "$REPO/scripts/extract-images.py" "$GP_EXE" "$images" > /dev/null
fi

# The logo is the largest square PNG (up to 512px, the biggest size hicolor defines) in the executable
best=; best_size=0
for f in "$images"/image_*_*x*.png; do
  [[ $f =~ _([0-9]+)x([0-9]+)\.png$ ]] || continue
  w=${BASH_REMATCH[1]}
  if [ "$w" = "${BASH_REMATCH[2]}" ] && [ "$w" -le 512 ] && [ "$w" -gt "$best_size" ]; then best=$f; best_size=$w; fi
done
if [ -z "$best" ]; then echo "error: no square PNG found in $GP_EXE" >&2; exit 1; fi

install -D -m 644 "$best" "$icons/${best_size}x${best_size}/apps/$ICON_NAME.png"
echo "Installed ${best_size}x${best_size} icon ($(basename "$best"))"

mapfile -d '' desktops < <(bottles_desktop_files)
if [ ${#desktops[@]} -gt 0 ]; then
  sed -i -e "s|^Icon=.*|Icon=$ICON_NAME|" -e "s|^StartupWMClass=.*|StartupWMClass=$GP_WM_CLASS|" "${desktops[@]}"
  printf 'Updated %s\n' "${desktops[@]}"
else
  mkdir -p "$apps"
  cat > "$apps/$ICON_NAME.desktop" <<DESKTOP
[Desktop Entry]
Name=Guitar Pro 8
Exec=flatpak run --command=bottles-cli com.usebottles.bottles run -p GuitarPro -b '$BOTTLE_NAME' -- %u
Type=Application
Terminal=false
Categories=AudioVideo;Audio;Music;
Icon=$ICON_NAME
Comment=Launch Guitar Pro using Bottles.
StartupWMClass=$GP_WM_CLASS
$marker
DESKTOP
  echo "Created $apps/$ICON_NAME.desktop"
fi
refresh
