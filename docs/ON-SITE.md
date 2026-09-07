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

## Network topology, for reference

```
home router  10.44.23.1        WireGuard SERVER, SSH open
desktop      10.44.23.5        WireGuard client, full tunnel (0.0.0.0/0)
GL.iNet Opal (office)          WireGuard CLIENT  -> home server
  └─ Voron Trident             office LAN, behind the Opal
```

The tunnel is healthy — the desktop handshakes fine. What does not work is
reaching *into* the office side. A scan of the whole `10.44.23.0/24` from the
desktop finds only the home router: the Opal does not answer on its own tunnel
address, and nothing behind it is reachable.

That is GL.iNet's default behaviour, not a broken tunnel. The WireGuard client
interface sits in a firewall zone that rejects input and does not forward into
the LAN, so the router is invisible from the server side and so is everything
behind it.

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

**Also needed, on the home side:** the Opal peer's `AllowedIPs` has to include
the office LAN subnet, not just the Opal's `/32`, or the home router has no
route to push printer-bound packets into the tunnel. That half you can do
remotely — the home router at `10.44.23.1` has SSH open. `sudo wg show` there
lists every peer with its allowed IPs and last handshake.

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
