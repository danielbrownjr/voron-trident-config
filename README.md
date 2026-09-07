# Voron Trident — Klipper config

Config for a 300 mm Voron Trident running Klipper + Mainsail.

| | |
|---|---|
| Kinematics | CoreXY, 300 × 300, Z max 250 |
| Main MCU | `/dev/ttyAMA0` (UART), pin map matches a BTT Octopus |
| X/Y/Z drivers | TMC2209, 0.7 A run / 0.4 A hold, 16 microsteps |
| Z | 3 independent motors, 80:16 gear ratio, `z_tilt` |
| Bed | Keenovo NTC 100K MGB18-104F39050L32, PID tuned |
| Probe | Klicky (**currently disabled**, see below) |
| Toolhead | SB2209 or SB2240 over CAN (**both currently disabled**) |
| Display | FYSETC Mini12864 with a custom "Starscream" theme |
| Extras | KAMP, Mainsail macros, OctoEverywhere, Crowsnest, Mobileraker |

## ⚠ This config will not start Klipper as-is

The whole toolhead is commented out. In `macros.cfg`:

```
#[include configure_extruder.cfg]
#[include sb2240.cfg]
#[include gantry_homing.cfg]
#[include klicky_probe/klicky-probe.cfg]
#[include sb2209.cfg]
```

…and the `[extruder]` block inside `printer.cfg` is commented out too. So the
active config has **no `[extruder]`, no `[probe]`, and no toolhead MCU**, while
`[z_tilt]` and `[bed_mesh]` — both of which need a probe — are still live.

The autosave block also still carries `[extruder]` PID values. Klipper rejects
config sections it cannot match to a real object, so that alone is very likely to
stop it booting until the extruder is back.

This looks like a printer mid-toolhead-swap rather than a broken config. Nothing
here has been "fixed" by guessing which toolhead is the live one — that choice is
still yours to make.

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
| `sb2209.cfg` / `sb2240.cfg` | The two toolhead options — CAN MCU, chamber sensor, part fan, hotend fan, Stealthburner neopixel. Pick one |
| `klicky_probe/` | Klicky probe macros. Needed by `z_tilt` and `bed_mesh` once re-enabled |
| `configure_extruder.cfg` | A single helper macro |
| `gantry_homing.cfg` | `homing_override` — note it also redefines `[idle_timeout]`, which `printer.cfg` already sets |

`KAMP/` and `klicky_probe/` are third-party. KAMP is managed by moonraker's
`update_manager`, so treat that folder as vendored and expect updates to
overwrite it.

## Using this repo

The repo root maps onto `~/printer_data/config/`. On the printer:

```bash
cd ~/printer_data/config && git init && git remote add origin <this repo> && git fetch && git checkout -f main
```

`.gitignore` covers the things that regenerate themselves: the
`printer-<timestamp>.cfg` copies Klipper writes on every `SAVE_CONFIG`, the
Mainsail config/gcode zip exports, and the tools' own rotated `.backup` files.

## Worth a look when you next touch it

Nothing below has been changed — these are observations, not edits.

- **`max_accel: 1000` with `max_velocity: 1000`.** The velocity is high and the
  acceleration is low for a Trident. If that pairing is a leftover from
  commissioning rather than a deliberate choice, it is leaving a lot on the table.
- **Stale bed mesh.** The saved `default` mesh is 4 × 3, but `[bed_mesh]` now asks
  for `probe_count: 5, 5`. The mesh predates the current settings; re-run
  `BED_MESH_CALIBRATE` once the probe is back.
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
