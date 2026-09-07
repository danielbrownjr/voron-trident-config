# On-site checklist

Everything that needs physical or LAN-side access, in the order worth doing it.
The Nitehawk and the Revo PZ are already at the office, so this is one visit for
the network, the toolhead, and backups.

**Running order, and why:**

1. **Network first.** Get remote access working before you change anything else.
   If the toolhead install misbehaves after you leave, that is the difference
   between fixing it from home and driving back.
2. **Backups second.** Once the reconcile is done and klipper-backup is running,
   every step of the toolhead install lands in git as its own commit. If
   something breaks you can diff instead of guess.
3. **Toolhead last**, with the other two as a safety net under it.

## Network topology

```
ArgonOne     10.44.23.1        WireGuard SERVER (Debian 12, Raspberry Pi)
                               also 192.168.1.150 on the home LAN
desktop      10.44.23.5        WireGuard client, full tunnel (0.0.0.0/0)
Opal         10.44.23.4        WireGuard client, peer name "tangly"
  └─ Trident 192.168.8.137     office LAN 192.168.8.0/24 (GL.iNet default)
```

SSH: `daniel@10.44.23.1` for the Pi, `pi@192.168.8.137` for the printer,
`root` + web-panel password for the Opal.

## Diagnosis — the home half is already done

The tunnel is healthy. The `tangly` peer handshakes every couple of minutes with
tens of GiB through it, so the Opal is connected and talking.

What was missing was a route: every peer in `wg0.conf` was a bare `/32`, so the
Pi had no idea `192.168.8.0/24` existed or which tunnel to send it down.
**Fixed** — `192.168.8.0/24` now sits on the `tangly` peer's `AllowedIPs`.
(It had briefly been added to the *Desktop* peer, which pointed the route at a
machine on the home LAN that cannot reach the office. Corrected.)

That leaves exactly one blocker, and it is on the Opal:

| Test, from the Pi | Result |
|---|---|
| `ping 10.44.23.4` — Opal on its tunnel IP | no reply |
| `ping 192.168.8.137` — printer behind it | no reply |

Both fail because GL.iNet puts the WireGuard client interface in a firewall zone
that rejects **input** and **forward**. The router is invisible from the server
side, and so is everything behind it. No amount of home-side configuration
changes that — it has to be opened from the Opal's own LAN.

## 1. Open the Opal's LAN to the tunnel

Connect to the Opal's LAN or its Wi-Fi, then:

1. `http://192.168.8.1` — the GL.iNet admin panel
2. VPN → WireGuard Client → **Options**
3. Enable **Allow Remote Access LAN**
4. Apply

GL.iNet's own guide for this exact case is
[Access WireGuard Client LAN from Server](https://docs.gl-inet.com/router/en/4/tutorials/wireguard_server_access_to_client_lan_side/).

Credentials, if you need SSH into it: user `root`, password is whatever you set
for the web admin panel — GL.iNet has no factory-default password and keeps
root in sync with the admin one.

**The home side is already done** — see the diagnosis above. After flipping the
toggle, verify from the Pi with `ping -c3 192.168.8.137` before you pack up.

## 2. Tailscale on the printer

Worth doing regardless, because it makes step 1 optional rather than critical:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

```bash
sudo tailscale up --ssh
```

NAT traversal handles itself. No router config, no port forwarding, no
`AllowedIPs` arithmetic, and `--ssh` gives a shell from anywhere even if the
WireGuard chain is unhealthy. After this the printer is reachable by its
Tailscale name from any of your devices.

## 3. Note the printer's addresses

While you have a shell:

```bash
hostname -I
```

Record the office LAN address. Add both it and the Tailscale name to
`~/.ssh/config` on the desktop so neither has to be remembered:

```
Host trident
    HostName <tailscale-name-or-ip>
    User pi
```

## 4. klipper-backup

Needs a shell, so it has been waiting on this visit. Full instructions in
[BACKUP.md](BACKUP.md) — **including the reconcile step, which matters**: this
repo has been cleaned and the Pi has not, so an unprepared first backup would
restore every file the cleanup removed.

Do this *before* the toolhead work, so the install is captured commit by commit.

## 5. The toolhead

The main event, and the reason the rest is worth doing first.
[NITEHAWK-INSTALL.md](NITEHAWK-INSTALL.md) is the full sequence: flash the
RP2040, paste the serial path, wire the PZ to the IO Port pads, enable the
include, switch Z to `probe:z_virtual_endstop`, then calibrate.

Two things to have in hand before you start:

- The PZ needs a **soldered pigtail** to the IO Port pads — bare 2.54 mm, no
  connector. Bring an iron, or make the pigtail beforehand.
- Nothing in that sequence is reversible from home. If you run out of time,
  stop at a booting config rather than a half-enabled one — the include stays
  commented and the printer comes up exactly as it does now.

## 6. Optional, while you are there

- **G-Code Shell Command extension** (KIAUH → Advanced) if you want the `GET_IP`
  macro in `network.cfg` to work. Low value now that the addresses are known and
  static — but it is also the only way to get a shell-ish escape hatch through
  Mainsail if the network breaks again.
- **Copy `nitehawk.cfg` and `archive/` onto the Pi** so they are in the config
  directory before backups start, otherwise the first backup deletes them from
  the repo. This is part of the reconcile in step 4, listed again because it is
  easy to miss.

## What you can still do remotely, without any of this

OctoEverywhere gives Mainsail's file editor write access to
`printer_data/config`. That covers config edits and the reconcile in
[BACKUP.md](BACKUP.md) — everything except installing software.
