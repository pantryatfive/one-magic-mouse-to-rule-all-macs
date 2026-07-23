#!/bin/bash
# Remove the Magic Mouse auto-reconnect helper from this Mac.
set -uo pipefail

LABEL="com.jolim.magicmouse-reconnect"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" \
      "$HOME/bin/magic-mouse-reconnect.sh" \
      "$HOME/bin/mouse-auto" \
      "$HOME/.magic-mouse-paused"

echo "Uninstalled."
echo "(blueutil left in place; 'brew uninstall blueutil' to remove it too.)"
