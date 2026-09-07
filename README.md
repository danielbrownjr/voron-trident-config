# Voron Trident — Klipper config

Config for a 300 mm Voron Trident running Klipper + Mainsail.

| | |
|---|---|
| Kinematics | CoreXY, 300 × 300, Z max 250 |
| Main MCU | `/dev/ttyAMA0` (UART), pin map matches a BTT Octopus |
| X/Y/Z drivers | TMC2209, 0.7 A run / 0.4 A hold, 16 microsteps |
| Z | 3 independent motors, 80:16 gear ratio, `z_tilt` |
| Bed | Keenovo NTC 100K MGB18-104F39050L32, PID tuned |
| Probe | E3D Revo Voron PZ Probe — piezo, probes with the nozzle (**not yet installed**) |
| Toolhead | LDO Nitehawk-SB, RP2040 over USB (**not yet installed**) |
| Hotend | E3D Revo Voron, standard heater core and thermistor |
| Display | FYSETC Mini12864 with a custom "Starscream" theme |
| Extras | KAMP, Mainsail macros, OctoEverywhere, Crowsnest, Mobileraker |

## Current state: no toolhead installed

The printer boots and homes X and Y. It has no toolhead on it at all, so there
is no extruder, no probe, and no way to trigger the Z endstop except by pressing
it with a finger.

That is deliberate, and the config matches it: every toolhead include in
`macros.cfg` is commented out, and so is `[include nitehawk.cfg]` at the bottom
of `printer.cfg`. Klipper will not start if it is told about an MCU that is not
plugged in, so the toolhead config stays inert until the hardware is on the
machine.

The incoming toolhead is an **LDO Nitehawk-SB** (RP2040, USB — not CAN) with an
**E3D Revo Voron PZ Probe**. It is fully written up in `nitehawk.cfg` and turned
on by following [docs/NITEHAWK-INSTALL.md](docs/NITEHAWK-INSTALL.md). Enabling it
is one atomic change, because the PZ probes with the nozzle and therefore
replaces the Z endstop at the same moment.

## Include tree

```
printer.cfg
├── mainsail.cfg            (vendored, managed by moonraker update_manager)
└── macros.cfg
    ├── print_start_end.cfg     PRINT_START / PRINT_END
    ├── z_tilt_settings.cfg     3-point z_tilt, 300 mm coordinates
    ├── display_pins.cfg        Mini12864 + neopixel
    ├── menu.cfg                custom LCD menu
    ├── filament.cfg            LOAD/UNLOAD_FILAMENT
    ├── display.cfg             Starscream glyphs and display_data
    ├── KAMP_Settings.cfg       (root copy — the one actually included)
    └── KAMP/                   Adaptive_Meshing, Line_Purge, Voron_Purge, Smart_Park
```

Not included by anything, kept deliberately:

| File | |
|---|---|
| `nitehawk.cfg` | The incoming toolhead — extruder, Revo heater and thermistor, PZ probe, fans, Stealthburner LEDs, onboard ADXL345. Inert until [docs/NITEHAWK-INSTALL.md](docs/NITEHAWK-INSTALL.md) is followed |
| `configure_extruder.cfg` | A single helper macro |
| `gantry_homing.cfg` | `homing_override` — note it also redefines `[idle_timeout]`, which `printer.cfg` already sets |

`KAMP/` is third-party and managed by moonraker's `update_manager`, so treat
that folder as vendored and expect updates to overwrite it.

`archive/` holds hardware that came off the machine — the SB2209 and SB2240
CAN toolboards with their UUIDs, and the Klicky probe macros and dock
coordinates. Nothing there is included by anything.

## Using this repo

The repo root maps onto `~/printer_data/config/`. On the printer:

```bash
cd ~/printer_data/config && git init && git remote add origin <this repo> && git fetch && git checkout -f main
```

`.gitignore` covers the things that regenerate themselves: the
`printer-<timestamp>.cfg` copies Klipper writes on every `SAVE_CONFIG`, the
Mainsail config/gcode zip exports, and the tools' own rotated `.backup` files.

For automated pushes from the printer itself, see
[docs/BACKUP.md](docs/BACKUP.md) — **read the reconcile section first**, because
the repo has been cleaned and the Pi has not, so an unprepared first backup
would undo it.

## Worth a look when you next touch it

Nothing below has been changed — these are observations, not edits.

- **`max_accel: 1000` with `max_velocity: 1000`.** The velocity is high and the
  acceleration is low for a Trident. If that pairing is a leftover from
  commissioning rather than a deliberate choice, it is leaving a lot on the table.
- **Stale bed mesh.** The saved `default` mesh is 4 × 3, but `[bed_mesh]` now asks
  for `probe_count: 5, 5`. It also insets to `35, 25` / `290, 278` to keep
  Klicky's offset probe on the bed — which the PZ, probing with the nozzle, no
  longer needs.
- **X endstop inversion changed recently.** `endstop_pin` went from `^!PB14` to
  `^PB14` between the 2026-08-14 backup and now.
- **`z_calibration` is installed but unused.** `moonraker.conf` has an
  `update_manager` entry for `protoloft/klipper_z_calibration`, but no
  `[z_calibration]` section exists in any config file.
- **`KAMP_Settings.cfg` exists twice** — once at the root (included, with its
  sub-includes commented out because `macros.cfg` does them directly) and once
  inside `KAMP/` (the pristine upstream copy). Harmless, but only the root one
  matters.
- **`[output_pin daylight]` has no macro.** The pin is defined on PC8 and the LCD
  menu has lights on/off entries, but the `daylight_on_off.cfg` stub that was
  meant to drive it was never written — it contained `[gcode macro: daylight_on]`,
  which is not valid Klipper syntax, and an empty body. It has been removed; the
  `[output_pin daylight]` definition is untouched.

## History

The first commit is the untouched 2026-09-07 Mainsail export, so every change
since is a reviewable diff. The original zip is still on the Desktop if you want
the `printer-*.cfg` backups that are excluded here.
