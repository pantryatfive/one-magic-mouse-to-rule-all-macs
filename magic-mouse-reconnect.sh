#!/bin/bash
# Auto-reconnect the Magic Mouse whenever it's paired and in range but not
# connected. Matched by NAME, so a changed Bluetooth address (which can happen
# after a re-pair) doesn't break reconnection.
#
# Design (see README "Design notes"):
#   * The loop GLANCES every POLL_INTERVAL (cheap: a local connection-state read).
#   * The expensive `--connect` attempt is gated on wall-clock elapsed time
#     (now - last_attempt >= interval), NOT on sleep — so system sleep/wake, App
#     Nap, or any process suspension can't leave it stuck (a long gap just reads
#     as "time to try").
#   * `interval` grows on failure (MIN -> x2 -> MAX) and is reset to MIN whenever
#     the mouse is observed connected. The reset is STATE-DERIVED (re-read each
#     tick), so a grown backoff can never leak into a new disconnect episode.
#   * Logging is TRANSITION-ONLY (lost / capped / reconnected), never per-tick,
#     so a week of absence is a handful of lines, not thousands.
#
# Runs continuously; installed as a launch agent by install.sh.
set -uo pipefail

# The name (or a substring of it) shown in System Settings > Bluetooth.
MOUSE_NAME="${MAGIC_MOUSE_NAME:-Magic Mouse}"
# Glance cadence — how often we check state (cheap). Also the backoff floor.
POLL_INTERVAL="${MAGIC_MOUSE_POLL:-3}"
# Backoff ceiling — the longest gap between failing reconnect attempts.
MAX_BACKOFF="${MAGIC_MOUSE_MAX_BACKOFF:-30}"
# While this file exists, the helper is paused (managed by the `mouse-auto` cmd).
PAUSE_FLAG="$HOME/.magic-mouse-paused"
# Must match the launchd plist's StandardOutPath/StandardErrorPath in install.sh.
LOG_FILE="/tmp/com.jolim.magicmouse-reconnect.log"
# Hard ceiling on the log, independent of the retry logic (~1 MB).
LOG_MAX_BYTES=1048576

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

# Separate concern (hard size ceiling): truncate an oversized log at startup.
if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$LOG_MAX_BYTES" ]; then
  : > "$LOG_FILE"
  log "log exceeded ${LOG_MAX_BYTES} bytes — truncated"
fi

log "started (watching for \"$MOUSE_NAME\", glance ${POLL_INTERVAL}s, backoff cap ${MAX_BACKOFF}s)"

# One-time startup self-check: confirm we can actually read Bluetooth. If this
# says DENIED, grant blueutil access in System Settings > Privacy & Security >
# Bluetooth (the permission is tied to blueutil, which launchd runs directly).
if "$BLUEUTIL" --paired >/dev/null 2>&1; then
  startup_addr="$(mouse_address)"
  log "Bluetooth access OK; resolved \"$MOUSE_NAME\" -> ${startup_addr:-<not found>}"
else
  log "Bluetooth access DENIED — enable blueutil under Privacy & Security > Bluetooth"
fi

# State machine (all initialised for `set -u`):
#   state        connected | disconnected | unknown (startup)
#   interval     current backoff between attempts (seconds)
#   last_attempt epoch of the last connect attempt's completion
#   capped_log   1 once we've logged that we hit MAX_BACKOFF (one-shot)
state="unknown"
interval="$POLL_INTERVAL"
last_attempt=0
capped_log=0

while true; do
  if [ -e "$PAUSE_FLAG" ]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  addr="$(mouse_address)"
  connected=0
  if [ -n "$addr" ] && [ "$("$BLUEUTIL" --is-connected "$addr" 2>/dev/null)" = "1" ]; then
    connected=1
  fi

  if [ "$connected" = "1" ]; then
    # Observed connected → reset backoff (state-derived) and log the edge if we
    # were previously trying to reconnect.
    if [ "$state" = "disconnected" ]; then
      log "reconnected $addr"
    fi
    state="connected"
    interval="$POLL_INTERVAL"
    capped_log=0
  else
    # Disconnected or absent → log the edge once on entering, then gate attempts.
    if [ "$state" != "disconnected" ]; then
      log "not connected — reconnecting (backoff up to ${MAX_BACKOFF}s)"
      state="disconnected"
      interval="$POLL_INTERVAL"
      last_attempt=0
    fi
    if [ -n "$addr" ]; then
      now="$(date +%s)"
      if [ "$(( now - last_attempt ))" -ge "$interval" ]; then
        # A real success is detected as `connected` on the next glance — don't
        # trust the exit code; just try, then grow the gap.
        "$BLUEUTIL" --connect "$addr" 2>/dev/null || true
        last_attempt="$(date +%s)"
        interval=$(( interval * 2 ))
        [ "$interval" -gt "$MAX_BACKOFF" ] && interval="$MAX_BACKOFF"
        if [ "$interval" -ge "$MAX_BACKOFF" ] && [ "$capped_log" = "0" ]; then
          log "mouse still absent — backed off to ${MAX_BACKOFF}s between tries"
          capped_log=1
        fi
      fi
    fi
  fi

  sleep "$POLL_INTERVAL"
done
