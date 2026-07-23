#!/bin/bash
# Install the Magic Mouse auto-reconnect helper on this Mac.
# Safe to re-run; it reinstalls and reloads cleanly.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/bin"
AGENTS="$HOME/Library/LaunchAgents"
LABEL="com.jolim.magicmouse-reconnect"
PLIST="$AGENTS/$LABEL.plist"

# 1. blueutil (Bluetooth CLI)
if ! command -v blueutil >/dev/null 2>&1; then
  echo "Installing blueutil via Homebrew..."
  brew install blueutil
fi

# 2. helper scripts -> ~/bin
mkdir -p "$BIN"
install -m 755 "$REPO_DIR/magic-mouse-reconnect.sh" "$BIN/magic-mouse-reconnect.sh"
install -m 755 "$REPO_DIR/mouse-auto" "$BIN/mouse-auto"

# 3. launch agent, rendered with THIS machine's paths (username-independent)
mkdir -p "$AGENTS"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$BIN/magic-mouse-reconnect.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/tmp/$LABEL.log</string>
	<key>StandardErrorPath</key>
	<string>/tmp/$LABEL.log</string>
</dict>
</plist>
EOF

# 4. (re)load
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo
echo "Installed and running."
echo "  mouse-auto status   # check it"
echo "  log: /tmp/$LABEL.log"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "  NOTE: add ~/bin to your PATH so 'mouse-auto' is found:"
     echo "        echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.zshrc" ;;
esac
