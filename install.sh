#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$REPO_DIR/protonvpn-qbittorrent-port.sh"
PLIST_LABEL="com.davidrios.protonvpn-qbittorrent-port"
PLIST_TEMPLATE="$REPO_DIR/$PLIST_LABEL.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Script not found at $SCRIPT_PATH" >&2
    exit 1
fi

if [[ ! -f "$PLIST_TEMPLATE" ]]; then
    echo "Plist template not found at $PLIST_TEMPLATE" >&2
    exit 1
fi

chmod +x "$SCRIPT_PATH"

if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
    echo "Unloading existing agent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

mkdir -p "$(dirname "$PLIST_DEST")"

echo "Generating plist at $PLIST_DEST"
sed -e "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" \
    -e "s|__HOME__|$HOME|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"

echo "Loading agent..."
launchctl load "$PLIST_DEST"

echo
echo "Installed: $PLIST_LABEL"
echo "Log: $HOME/Library/Logs/protonvpn-qbittorrent-port.log"
