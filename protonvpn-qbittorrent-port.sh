#!/bin/bash
set -uo pipefail

GATEWAY="10.2.0.1"
QBT_CONFIG="$HOME/.config/qBittorrent/qBittorrent.ini"
QBT_APP_NAME="qbittorrent"
LOG_FILE="$HOME/Library/Logs/protonvpn-qbittorrent-port.log"
NATPMPC="/opt/homebrew/bin/natpmpc"
LOCK_DIR="/tmp/protonvpn-qbittorrent-port.lock"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "Another instance is running (lock held at $LOCK_DIR), exiting"
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

query_port() {
    local proto="$1"
    "$NATPMPC" -a 1 0 "$proto" 60 -g "$GATEWAY" 2>&1 \
        | awk '/Mapped public port/ {print $4; exit}'
}

get_forwarded_port() {
    local udp tcp
    udp=$(query_port udp) || return 1
    tcp=$(query_port tcp) || return 1
    if [[ -z "$udp" || -z "$tcp" ]]; then
        return 1
    fi
    if [[ "$udp" != "$tcp" ]]; then
        log "WARN: udp port ($udp) != tcp port ($tcp), using tcp"
    fi
    echo "$tcp"
}

get_current_port() {
    awk -F= '/^Session\\Port=/ {print $2; exit}' "$QBT_CONFIG"
}

is_qbt_running() {
    pgrep -x "$QBT_APP_NAME" >/dev/null 2>&1
}

quit_qbt() {
    osascript -e "tell application \"$QBT_APP_NAME\" to quit" 2>/dev/null || true
    for _ in $(seq 1 30); do
        is_qbt_running || return 0
        sleep 1
    done
    log "qBittorrent did not quit gracefully, force killing"
    pkill -x "$QBT_APP_NAME" 2>/dev/null || true
    sleep 2
}

start_qbt() {
    open -a "$QBT_APP_NAME"
}

update_port_in_config() {
    local new_port="$1" tmp
    tmp=$(mktemp)
    awk -v port="$new_port" 'BEGIN {FS=OFS="="} /^Session\\Port=/ {$2=port} {print}' \
        "$QBT_CONFIG" > "$tmp"
    mv "$tmp" "$QBT_CONFIG"
}

main() {
    if [[ ! -f "$QBT_CONFIG" ]]; then
        log "qBittorrent config not found at $QBT_CONFIG"
        exit 1
    fi

    local new_port
    new_port=$(get_forwarded_port) || {
        log "Could not query forwarded port (VPN down or port forwarding off)"
        exit 0
    }

    local current_port
    current_port=$(get_current_port)

    if [[ "$new_port" == "$current_port" ]]; then
        log "Port unchanged ($current_port)"
        exit 0
    fi

    log "Port changed: $current_port -> $new_port"

    local was_running=0
    if is_qbt_running; then
        was_running=1
        log "Quitting qBittorrent"
        quit_qbt
    fi

    update_port_in_config "$new_port"
    log "Config updated"

    if [[ "$was_running" -eq 1 ]]; then
        log "Starting qBittorrent"
        start_qbt
    fi
}

main "$@"
