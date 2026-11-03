#!/usr/bin/bash
# Check that the tools a step needs are present, reporting everything missing at once.
# Usage: check-deps.sh [all|bottles|icon|fonts|inhibit]...
set -uo pipefail
source "$(dirname "$0")/common.sh"

# command -> package hint (Fedora names)
declare -A hint=(
  [flatpak]=flatpak
  [python3]=python3
  [curl]=curl
  [sha256sum]=coreutils
  [jq]=jq
  [pw-dump]=pipewire-utils
  [pw-record]=pipewire-utils
  [kde-inhibit]=kde-cli-tools
  [systemctl]=systemd
)

declare -A needs=(
  [bottles]="flatpak"
  [icon]="python3"
  [fonts]="curl sha256sum"
  [inhibit]="jq pw-dump pw-record kde-inhibit systemctl"
)

groups=("$@")
[ ${#groups[@]} -eq 0 ] || [ "${groups[0]}" = all ] && groups=(bottles icon fonts inhibit)

missing=()
for g in "${groups[@]}"; do
  [ -n "${needs[$g]:-}" ] || { echo "check-deps: unknown group '$g'" >&2; exit 2; }
  for cmd in ${needs[$g]}; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
done

[ ${#missing[@]} -eq 0 ] && exit 0

echo "error: missing dependencies:" >&2
printf '%s\n' "${missing[@]}" | sort -u | while read -r m; do
  printf '  %-26s (%s)\n' "$m" "${hint[$m]:-}" >&2
done
exit 1
