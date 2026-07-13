#!/bin/zsh
set -euo pipefail

CLEANUP_SCRIPT="/Users/gurindersingh/Documents/Developer/CommandCenter/scripts/vpn-zombie-cleanup.sh"
LOG_FILE="$HOME/Library/Logs/vpn-heal.log"

mkdir -p "$(dirname "$LOG_FILE")"

run_heal() {
  printf "[%s] running vpn cleanup\n" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  /bin/zsh "$CLEANUP_SCRIPT" >> "$LOG_FILE" 2>&1 || true
}

# Run once at login
run_heal

# Watch for wake events and heal again
/usr/bin/log stream --style compact --predicate 'eventMessage CONTAINS[c] "Wake"' | while IFS= read -r _line; do
  run_heal
done
