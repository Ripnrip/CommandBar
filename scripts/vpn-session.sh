#!/bin/zsh
set -euo pipefail

LOG_FILE="$HOME/Library/Logs/vpn-session.log"
mkdir -p "$(dirname "$LOG_FILE")"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf "[%s] %s\n" "$(timestamp)" "$*" | tee -a "$LOG_FILE"; }

cleanup() {
  log "cleanup: stopping watcher"
  if [[ -n "${WATCHER_PID:-}" ]]; then
    kill "$WATCHER_PID" >/dev/null 2>&1 || true
    wait "$WATCHER_PID" 2>/dev/null || true
  fi
  if [[ "${VPN_KIND:-}" == "nordvpn" ]]; then
    log "cleanup: disconnecting NordVPN"
    nordvpn disconnect >/dev/null 2>&1 || true
  fi
  log "cleanup: complete"
}
trap cleanup EXIT INT TERM

# Optional periodic heal (disabled by default)
HEAL_INTERVAL="${HEAL_INTERVAL:-0}"
CLEANUP_SCRIPT="/Users/gurindersingh/Documents/Developer/CommandCenter/scripts/vpn-zombie-cleanup.sh"
if [[ "$HEAL_INTERVAL" != "0" && -x "$CLEANUP_SCRIPT" ]]; then
  log "starting periodic heal every ${HEAL_INTERVAL}s"
  (
    while true; do
      sleep "$HEAL_INTERVAL"
      /bin/zsh "$CLEANUP_SCRIPT" >> "$LOG_FILE" 2>&1 || true
    done
  ) &
  WATCHER_PID=$!
fi

if command -v nordvpn >/dev/null 2>&1; then
  VPN_KIND="nordvpn"
  NORDVPN_TARGET="${NORDVPN_TARGET:-Montreal}"
  log "starting NordVPN connection to ${NORDVPN_TARGET}"
  nordvpn connect "${NORDVPN_TARGET}"
  log "connected. press Ctrl+C to disconnect and cleanup"
  while true; do sleep 3600; done
elif command -v tailscale >/dev/null 2>&1; then
  log "starting Tailscale"
  tailscale up
  log "connected. press Ctrl+C to stop session"
  while true; do sleep 3600; done
else
  log "no supported VPN CLI found (nordvpn or tailscale)"
  exit 1
fi
