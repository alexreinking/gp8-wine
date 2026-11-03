#!/usr/bin/bash
# Copyright (C) 2026 Alex Reinking
# SPDX-License-Identifier: GPL-3.0-or-later
# Inhibit screen lock/blanking while Guitar Pro (under Wine) is outputting non-silent audio.
# Wine streams stay "running"/uncorked while paused (feeding zeros), so sample the signal.
pattern='Guitar Pro'
# Keep the inhibitor through quiet stretches (rests, a muted track) shorter than this, or the
# screen could lock the instant playback goes quiet if the idle timer has already run out.
silence_secs=${GP_INHIBIT_SILENCE_SECS:-60}
last_audio=0
inhibit_pid=

# Prints ids of PipeWire playback-stream nodes matching $pattern
stream_nodes() {
  pw-dump 2>/dev/null | jq -r --arg p "$pattern" '.[]
    | select(.type == "PipeWire:Interface:Node" and .info.state == "running"
             and .info.props["media.class"] == "Stream/Output/Audio")
    | select((.info.props["application.name"] // "") | test($p; "i"))
    | .id'
}

# True if any matching stream has non-zero samples in a ~1s window.
# The capture stream identifies as pavucontrol, which Plasma's recording indicator ignores
# (it is a level meter, like pavucontrol's); otherwise the tray flashes "recording" every poll.
playing() {
  local id
  for id in $(stream_nodes); do
    # strip the 24-byte .snd header, look for any non-NUL byte
    if [ -n "$(timeout 1 pw-record --target "$id" \
         -P '{ "stream.capture.sink": true, "application.id": "org.PulseAudio.pavucontrol" }' \
         --format s16 --rate 8000 --channels 1 - 2>/dev/null \
         | tail -c +25 2>/dev/null | tr -d '\0' 2>/dev/null | head -c 1)" ]; then
      return 0
    fi
  done
  return 1
}

release() {
  [ -n "$inhibit_pid" ] || return
  pkill -P "$inhibit_pid"; kill "$inhibit_pid" 2>/dev/null
  inhibit_pid=
}
trap 'release; exit' INT TERM

while sleep 2; do
  if playing; then
    last_audio=$SECONDS
    if [ -z "$inhibit_pid" ] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
      kde-inhibit --power --screenSaver sleep infinity &
      inhibit_pid=$!
      echo "$(date +%T) inhibiting"
    fi
  elif [ -n "$inhibit_pid" ] && [ $((SECONDS - last_audio)) -ge "$silence_secs" ]; then
    release
    echo "$(date +%T) released (silent for ${silence_secs}s)"
  fi
done
