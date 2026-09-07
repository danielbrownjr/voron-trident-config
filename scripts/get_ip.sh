#!/usr/bin/env bash
# Print the printer's primary LAN address, for GET_IP in network.cfg.
#
# `ip route get` is a kernel routing-table lookup, not a connection - nothing is
# sent to 1.1.1.1. It is just the tidiest way to ask "which of my addresses
# would I use to reach the outside world", which is the one you actually want.
# Plain `hostname -I` lists every address including docker and tailscale ones.
set -uo pipefail

ip_addr=$(ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}')

if [ -z "${ip_addr}" ]; then
    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

echo "hostname : $(hostname).local"
echo "ip       : ${ip_addr:-unknown}"
