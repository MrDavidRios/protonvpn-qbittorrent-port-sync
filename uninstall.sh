#!/bin/bash
set -euo pipefail

PLIST_LABEL="com.davidrios.protonvpn-qbittorrent-port"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [[ -f "$PLIST_DEST" ]]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm "$PLIST_DEST"
    echo "Uninstalled: $PLIST_LABEL"
else
    echo "Not installed (no plist at $PLIST_DEST)"
fi
