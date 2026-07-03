#!/bin/bash

# Define paths
WATCHER_SCRIPT="$HOME/.ia_companion_watcher.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/com.iacompanion.watcher.plist"
REPO_WATCHER="$(cd "$(dirname "$0")" && pwd)/watcher.sh"

echo "Copying watcher script to $WATCHER_SCRIPT..."
cp "$REPO_WATCHER" "$WATCHER_SCRIPT"
chmod +x "$WATCHER_SCRIPT"

echo "Creating LaunchAgent plist..."
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.iacompanion.watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$WATCHER_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/com.iacompanion.watcher.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/com.iacompanion.watcher.err</string>
</dict>
</plist>
EOF

echo "Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✅ Background watcher installed successfully!"
