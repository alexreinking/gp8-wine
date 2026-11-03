#!/usr/bin/bash
# Ensure the Segoe UI fonts (from mrbvrz/segoe-ui-linux, pinned) are in the bottle and
# registered with Wine, and that Wine isn't told to substitute Times New Roman for them.
# Fonts are fetched at install time and verified against fonts.sha256; they are not stored in this repo.
set -euo pipefail
source "$(dirname "$0")/common.sh"

commit=a89213b7136da6dd5c3638db1f2c6e814c40fa84
url=https://raw.githubusercontent.com/mrbvrz/segoe-ui-linux/$commit/font
dest=$BOTTLE_DIR/drive_c/windows/Fonts

"$(dirname "$0")/ensure-bottle.sh"
mkdir -p "$dest"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fetched=0
while read -r sum name; do
  if [ -f "$dest/$name" ] && [ "$(sha256sum < "$dest/$name" | cut -d' ' -f1)" = "$sum" ]; then
    continue
  fi
  curl -fsSL -o "$tmp/$name" "$url/$name"
  echo "$sum  $tmp/$name" | sha256sum -c --quiet -
  install -m 644 "$tmp/$name" "$dest/$name"
  fetched=$((fetched + 1))
done < "$REPO/fonts.sha256"

echo "Segoe UI fonts: $fetched installed, $(wc -l < "$REPO/fonts.sha256") total present"

# Register the fonts in Wine's Fonts key (like Windows does) and delete the default
# "Segoe UI" -> "Times New Roman" replacements some prefixes are created with.
declare -A face=(
  [segoeui.ttf]="Segoe UI"                    [segoeuib.ttf]="Segoe UI Bold"
  [segoeuii.ttf]="Segoe UI Italic"            [segoeuiz.ttf]="Segoe UI Bold Italic"
  [segoeuil.ttf]="Segoe UI Light"             [seguili.ttf]="Segoe UI Light Italic"
  [segoeuisl.ttf]="Segoe UI Semilight"        [seguisli.ttf]="Segoe UI Semilight Italic"
  [seguisb.ttf]="Segoe UI Semibold"           [seguisbi.ttf]="Segoe UI Semibold Italic"
  [seguibl.ttf]="Segoe UI Black"              [seguibli.ttf]="Segoe UI Black Italic"
  [seguiemj.ttf]="Segoe UI Emoji"             [seguisym.ttf]="Segoe UI Symbol"
  [seguihis.ttf]="Segoe UI Historic"
)

# Print the body of a [section] of a Wine .reg file (section passed via env: awk -v mangles backslashes)
reg_section() { HDR="[$2]" awk 'index($0, ENVIRON["HDR"]) == 1 {p=1; next} /^\[/ {p=0} p' "$1"; }

fonts_key='Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts'
repl_key='Software\\Wine\\Fonts\\Replacements'

registered=$(reg_section "$BOTTLE_DIR/system.reg" "$fonts_key")
replaced=$(reg_section "$BOTTLE_DIR/user.reg" "$repl_key")
need=0
for file in "${!face[@]}"; do
  grep -qiF "\"${face[$file]} (TrueType)\"=\"$file\"" <<< "$registered" || need=1
done
grep -q '^"Segoe UI\( Semibold\)\?"=' <<< "$replaced" && need=1

if [ $need -eq 0 ]; then
  echo "Segoe UI fonts already registered"
  exit 0
fi

reg=$BOTTLE_DIR/drive_c/windows/temp/gp8-fonts.reg
mkdir -p "$(dirname "$reg")"
trap 'rm -f "$reg"; rm -rf "$tmp"' EXIT
{
  printf 'Windows Registry Editor Version 5.00\r\n\r\n'
  printf '[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]\r\n'
  for file in "${!face[@]}"; do
    printf '"%s (TrueType)"="%s"\r\n' "${face[$file]}" "$file"
  done
  printf '\r\n[HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements]\r\n'
  printf '"Segoe UI"=-\r\n"Segoe UI Semibold"=-\r\n'
} > "$reg"

# Ask the live wineserver (not the .reg files, which are only written on shutdown)
live_query() { $BOTTLES_CLI shell -b "$BOTTLE_NAME" -i "reg query '$1' $2" 2>&1; }

applied() {
  live_query "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" "/v 'Segoe UI Black (TrueType)'" \
    | grep -qi seguibl.ttf || return 1
  ! live_query "HKCU\\Software\\Wine\\Fonts\\Replacements" "" | grep -q '^ *Segoe UI '
}

# The import can be silently lost right after an install while the prefix settles, so verify and retry.
for attempt in 1 2 3; do
  $BOTTLES_CLI shell -b "$BOTTLE_NAME" -i "regedit /S 'C:\\windows\\temp\\gp8-fonts.reg'" > /dev/null 2>&1 || true
  if applied; then
    echo "Registered Segoe UI fonts with Wine"
    # Restart the bottle so the registry is flushed to disk and the next launch starts clean,
    # unless Guitar Pro is running (we'd close the user's session).
    pgrep -f 'GuitarPro\.exe' > /dev/null || stop_bottle
    exit 0
  fi
  echo "Font registration not applied yet (attempt $attempt/3), retrying" >&2
  sleep 5
done
echo "error: could not register the Segoe UI fonts with Wine" >&2
exit 1
