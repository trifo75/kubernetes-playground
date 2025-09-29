#!/usr/bin/env bash
set -euo pipefail

BRIDGE="kube_br0"

# 1) Bridge CIDR
BRIDGE_CIDR="$(ip -o -4 addr show dev "$BRIDGE" 2>/dev/null | awk '{print $4}')"
if [ -z "$BRIDGE_CIDR" ]; then
  echo "ERROR: brigdge interface not found: $BRIDGE"
  exit 1
fi

# 2) Host interface (to route traffic through)
HOST_IF="$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)"
if [ -z "$HOST_IF" ]; then
  echo "Hiba: nem sikerült meghatározni a kifelé menő interfészt"
  echo "ERROR: unable to identify uplink interface name"
  exit 1
fi

echo "Bridge CIDR: $BRIDGE_CIDR"
echo "Host interface: $HOST_IF"

# 3) Enabling az IP forwarding (immediately)
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

# 4) Add NAT (MASQUERADE) when it is not there yet
sudo iptables -t nat -C POSTROUTING -s "$BRIDGE_CIDR" ! -d "$BRIDGE_CIDR" -o "$HOST_IF" -j MASQUERADE 2>/dev/null \
  || sudo iptables -t nat -A POSTROUTING -s "$BRIDGE_CIDR" ! -d "$BRIDGE_CIDR" -o "$HOST_IF" -j MASQUERADE

# 5) Enable FORWARE (let packages through in and out based on connection tracking)
sudo iptables -C FORWARD -i "$HOST_IF" -o "$BRIDGE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
  || sudo iptables -A FORWARD -i "$HOST_IF" -o "$BRIDGE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

sudo iptables -C FORWARD -i "$BRIDGE" -o "$HOST_IF" -j ACCEPT 2>/dev/null \
  || sudo iptables -A FORWARD -i "$BRIDGE" -o "$HOST_IF" -j ACCEPT

echo "iptables rules set."
echo "net.ipv4.ip_forward is enabled (temporarily)."
