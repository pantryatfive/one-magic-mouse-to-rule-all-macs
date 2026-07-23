#!/bin/bash
# Auto-reconnect the Magic Mouse whenever it's paired and in range but not
# connected. The mouse is matched by NAME, so a changed Bluetooth address
# (which can happen after a re-pair) doesn't break reconnection.
#
# Runs continuously; installed as a launch agent by install.sh.
set -uo pipefail

# The name (or a substring of it) shown in System Settings > Bluetooth.
MOUSE_NAME="${MAGIC_MOUSE_NAME:-Magic Mouse}"
# Seconds between checks. A check is a cheap yes/no query, not a reconnect.
POLL_INTERVAL="${MAGIC_MOUSE_POLL:-3}"
# While this file exists, the helper is paused (managed by the `mouse-auto` cmd).
PAUSE_FLAG="$HOME/.magic-mouse-paused"

BLUEUTIL="$(command -v blueutil || echo /opt/homebrew/bin/blueutil)"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

if [ ! -x "$BLUEUTIL" ]; then
  log "blueutil not found — run install.sh first."
  exit 1
fi

# Address of the first paired device whose name contains MOUSE_NAME.
mouse_address() {
  "$BLUEUTIL" --paired 2>/dev/null \
    | grep -i "$MOUSE_NAME" \
    | sed -n 's/^address: \([0-9a-fA-F:-]*\).*/\1/p' \
    | head -n1
}

log "started (watching for \"$MOUSE_NAME\", every ${POLL_INTERVAL}s)"
while true; do
  if [ ! -e "$PAUSE_FLAG" ]; then
    addr="$(mouse_address)"
    if [ -n "$addr" ] && [ "$("$BLUEUTIL" --is-connected "$addr" 2>/dev/null)" = "0" ]; then
      "$BLUEUTIL" --connect "$addr" 2>/dev/null && log "reconnected $addr"
    fi
  fi
  sleep "$POLL_INTERVAL"
done
