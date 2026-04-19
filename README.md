# protonvpn-qbittorrent-port

Keeps qBittorrent's listening port in sync with the port forwarded by ProtonVPN, on macOS.

ProtonVPN's NAT-PMP-assigned forwarded port can change whenever the VPN reconnects. Without an external sync, qBittorrent keeps using its old (now-blocked) port and incoming connections silently fail. This repo polls ProtonVPN every hour, and if the port has changed, quits qBittorrent, rewrites its config, and relaunches it.

## Requirements

- macOS
- [Homebrew](https://brew.sh) for installing `libnatpmp`:
  ```
  brew install libnatpmp
  ```
- ProtonVPN connected with **port forwarding enabled** (Settings → Advanced → "Allow alternative routing & port forwarding")
- qBittorrent installed at `/Applications/qbittorrent.app`
- qBittorrent config at `~/.config/qBittorrent/qBittorrent.ini` (default location)

## Install

```
git clone <this-repo> ~/Projects/protonvpn-qbittorrent-port
cd ~/Projects/protonvpn-qbittorrent-port
./install.sh
```

`install.sh` is idempotent — re-run it any time to regenerate the plist and reload the agent (e.g. after pulling updates).

## Uninstall

```
./uninstall.sh
```

Unloads the launchd agent and removes the generated plist. Doesn't touch the repo or qBittorrent.

## How it works

### The script

`protonvpn-qbittorrent-port.sh` does:

1. Asks ProtonVPN's NAT-PMP gateway (`10.2.0.1`) for the currently-forwarded port using `natpmpc`.
2. Reads `Session\Port` from `~/.config/qBittorrent/qBittorrent.ini`.
3. If they differ:
   - Quits qBittorrent gracefully (via AppleScript), force-killing after 30 s if needed.
   - Rewrites the `Session\Port` line in the `.ini`.
   - Relaunches qBittorrent.
4. If qBittorrent wasn't running, just updates the config.
5. If the VPN is down or port forwarding is off, logs and exits cleanly — no config change.

A `mkdir`-based lock at `/tmp/protonvpn-qbittorrent-port.lock` prevents concurrent runs from racing.

### The launchd agent

A user-level `launchd` agent runs the script every hour (`StartInterval = 3600`) and once at load time (`RunAtLoad = true`). The agent's plist lives at `~/Library/LaunchAgents/com.davidrios.protonvpn-qbittorrent-port.plist` after install.

### The plist template

`launchd` requires **absolute paths** in plists — no `~`, no `$HOME`, no relative paths. That makes it impossible to commit a single plist that works for anyone who clones the repo, since the absolute path depends on where they put the repo and what their username is.

So the repo only contains a *template*:

```xml
<string>__SCRIPT_PATH__</string>
...
<string>__HOME__/Library/Logs/protonvpn-qbittorrent-port.stdout.log</string>
```

`__SCRIPT_PATH__` and `__HOME__` are placeholder tokens. `install.sh` figures out the real paths at install time:

```bash
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$REPO_DIR/protonvpn-qbittorrent-port.sh"
```

…runs `sed` to substitute the placeholders with real paths…

```bash
sed -e "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" \
    -e "s|__HOME__|$HOME|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"
```

…and writes the resulting plist to `~/Library/LaunchAgents/`. The generated plist is outside the repo, so git never sees it. The repo stays portable.

## Logs

```
tail -f ~/Library/Logs/protonvpn-qbittorrent-port.log
```

Per-run script output. Each entry is timestamped. `stdout`/`stderr` from the agent itself go to sibling `.stdout.log` / `.stderr.log` files (usually empty).

## Useful commands

| Action | Command |
|---|---|
| Check loaded | `launchctl list \| grep protonvpn-qbittorrent` |
| Trigger now | `launchctl start com.davidrios.protonvpn-qbittorrent-port` |
| Run script directly | `~/Projects/protonvpn-qbittorrent-port/protonvpn-qbittorrent-port.sh` |
| Reload after editing plist template | `./install.sh` |
| Stop / disable | `./uninstall.sh` |

## Notes

- The hourly cadence is set in the plist template (`StartInterval`). Change to taste, or swap for `StartCalendarInterval` for on-the-hour scheduling. Re-run `install.sh` after editing.
- The label `com.davidrios.protonvpn-qbittorrent-port` is a reverse-DNS-style identifier used by launchd. If you fork this, change it in `install.sh`, `uninstall.sh`, and the template filename to match your own domain.
