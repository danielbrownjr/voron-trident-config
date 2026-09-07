# Automated backup from the printer to this repo

[`klipper-backup`](https://github.com/Staubgeborener/klipper-backup) is the tool
for this. It rsyncs the paths you list into `~/config_backup`, commits, and
pushes. It can run on boot, on a timer, on file change, or from a Mainsail
macro.

## ⚠ Do the reconcile first, or the first push undoes the cleanup

This repo does **not** match what is on the Pi right now. The repo is a cleaned
version of the 2026-09-07 export:

| On the Pi | In this repo |
|---|---|
| `daylight_on_off.cfg`, `display_backup.cfg`, `display_backup02.cfg` | deleted |
| `sb2209.cfg`, `sb2240.cfg`, `klicky_probe/` at the root | moved to `archive/` |
| `printer.cfg` with a duplicate `[virtual_sdcard]` and three stacked `SAVE_CONFIG` blocks | deduped, collapsed to one |
| no `nitehawk.cfg` | present, inert |

`klipper-backup` pushes **whatever is in the config directory**. Point it at this
repo before reconciling and its first commit will faithfully restore every one
of those files and revert `printer.cfg`. The cleanup is not lost — it is in git
history — but you would be starting over.

Also worth knowing: the Pi's `printer.cfg` may have moved on since 7 September.
Any `SAVE_CONFIG` since then (a PID tune, a mesh) is on the Pi and not here.

### Reconcile

On the Pi, get the current state and compare it against the repo before
overwriting anything in either direction:

```bash
cd ~ && tar czf config-preflight-$(date +%F).tar.gz printer_data/config
```

```bash
git clone https://github.com/danielbrownjr/voron-trident-config ~/vtc-compare
```

```bash
diff -ru ~/printer_data/config ~/vtc-compare --exclude=.git --exclude='printer-[0-9]*_[0-9]*.cfg'
```

Read that diff. Where the repo is right (the deletions, the collapsed autosave
block), copy the repo's version onto the Pi. Where the Pi is right (anything
Klipper has saved since the export), keep the Pi's and let the first backup
commit it. Then delete `~/vtc-compare`.

Copy `nitehawk.cfg` and `archive/` onto the Pi as part of this — they belong in
the config directory so the backup picks them up.

---

## Setting it up

### 1. A fine-grained token, scoped to this repo only

GitHub → Settings → Developer settings → Personal access tokens →
**Fine-grained tokens** → Generate new token.

- **Only select repositories:** `voron-trident-config`, nothing else
- **Repository permissions:** Contents → **Read and write**; Metadata → Read-only

Scoping it to the one repo means a leaked token can rewrite this config and
nothing else. Note the expiry date — when it lapses, backups fail silently
unless you have `allow_empty_commits="true"` and are watching for the heartbeat
commits to stop.

### 2. Install

```bash
curl -fsSL get.klipperbackup.xyz | bash
```

```bash
~/klipper-backup/install.sh
```

The installer asks for the token and offers the optional pieces — backup on
boot, backup on file change, a Moonraker `update_manager` entry so it updates
itself, and a Mainsail macro to trigger it by hand. You can re-run `install.sh`
later to add any of them.

### 3. Configure `~/klipper-backup/.env`

Mandatory:

```
github_token="github_pat_..."
github_username="danielbrownjr"
github_repository="voron-trident-config"
```

Paths — the whole config directory:

```
backupPaths=( \
"printer_data/config/*" \
)
```

**Mirror this repo's `.gitignore` into the `exclude` array.** `klipper-backup`
generates `.gitignore` from `exclude=()`, so anything not listed there comes
back:

```
exclude=( \
"printer-[0-9]*_[0-9]*.cfg" \
"config-*.zip" \
"gcodes-*.zip" \
"*.backup" \
"*.bak" \
"crowsnest.conf.[0-9]*" \
"*.log" \
"*.swp" \
"*.tmp" \
)
```

`.env` and `secrets.conf` are excluded by default. That matters here — **this
repo is public**, and `.env` holds the token. `.env` lives in
`~/klipper-backup/`, outside `backupPaths`, so it should never be in scope
anyway; the repo `.gitignore` names it as well, as belt and braces.

Worth setting:

```
commit_username="trident"
commit_email="backup@trident"
use_filenames_as_commit_msg="true"
```

The last one puts the changed filenames in the commit subject, which makes the
history readable at a glance — "printer.cfg" rather than a timestamp.

### 4. Pull, don't clone, on this machine

The Windows working copy at `Documents/Coding/trident-config` is a second
checkout. Once the printer starts pushing, `git pull` there before editing, or
you will be reconciling by hand.

## Restoring

```bash
git clone https://github.com/danielbrownjr/voron-trident-config ~/restore
```

Then copy what you need into `printer_data/config`. Remember the
`printer-*.cfg` snapshots are deliberately not in the repo — Klipper regenerates
those, and git history is the real record.
