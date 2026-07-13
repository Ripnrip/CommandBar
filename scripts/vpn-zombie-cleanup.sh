#!/bin/zsh
set -euo pipefail

pkill -f -i nord || true
pkill -f -i tailscale || true

for service in "Wi-Fi" "USB 10/100/1000 LAN" "Ethernet"; do
  networksetup -setnetworkserviceenabled "$service" off >/dev/null 2>&1 || true
  networksetup -setnetworkserviceenabled "$service" on >/dev/null 2>&1 || true
done

dscacheutil -flushcache || true
killall -HUP mDNSResponder || true

printf "VPN cleanup complete\n\n"
printf "Top IPv4 routes:\n"
netstat -rn -f inet | head -40
printf "\nDNS nameservers:\n"
scutil --dns | /usr/bin/grep -E 'nameserver\[[0-9]+\]' || true
