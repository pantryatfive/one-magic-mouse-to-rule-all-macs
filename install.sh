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
# Make `mouse-auto` findable by name: ensure ~/bin is on PATH. Append a marked
# line to ~/.zshrc if it's missing (idempotent — safe to re-run).
case ":$PATH:" in
  *":$BIN:"*) ;;  # already active in this shell
  *)
    if ! grep -q '# magic-mouse-auto PATH' "$HOME/.zshrc" 2>/dev/null; then
      printf '\n# magic-mouse-auto PATH\nexport PATH="$HOME/bin:$PATH"\n' >> "$HOME/.zshrc"
      echo "  Added ~/bin to your PATH in ~/.zshrc."
    fi
    echo "  Open a new terminal (or run 'source ~/.zshrc') so 'mouse-auto' works." ;;
esac
