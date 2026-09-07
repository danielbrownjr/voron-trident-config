#!/usr/bin/env bash
# Print every address this machine answers on, for GET_IP in network.cfg.
#
# Deliberately lists ALL interfaces rather than picking one. This printer sits
# on an office LAN and reaches home over a WireGuard tunnel, so it has at least
# two addresses and the useful one depends entirely on where you are asking
# from. A single "the" IP would be wrong half the time.
#
# The default-route interface is marked. On a split-tunnel WireGuard setup that
# is the office LAN address - reachable only from the office. The wg* address is
# the one to SSH to from the other end of the tunnel.
set -uo pipefail

echo "hostname : $(hostname).local"

default_if=$(ip -4 route show default 2>/dev/null \
    | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}')

ip -4 -o addr show scope global 2>/dev/null | while read -r _ iface _ cidr _; do
    addr=${cidr%%/*}
    if [ "${iface}" = "${default_if}" ]; then
        printf '%-8s : %s   (default route)\n' "${iface}" "${addr}"
    else
        printf '%-8s : %s\n' "${iface}" "${addr}"
    fi
done
