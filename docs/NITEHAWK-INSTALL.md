# Installing the Nitehawk-SB + Revo PZ Probe

Everything for this toolhead is already written and committed, and **all of it is
inert**. `nitehawk.cfg` is not included by anything, so the printer boots today
exactly as it does now.

Do not uncomment the include on its own. `nitehawk.cfg` declares a second `[mcu]`
on USB, and Klipper refuses to start when an MCU it has been told about is not
present — and step 5 below has to happen in the same sitting, because the Z
endstop changes at the same time.

## Why this is one atomic change

Right now `[stepper_z]` homes against a physical switch on `^PA0`. The PZ probes
with the nozzle, so it becomes the Z endstop via `probe:z_virtual_endstop`. Those
two cannot coexist: Klipper rejects a `[stepper_z]` that has both
`position_endstop` and a virtual endstop. So the toolhead going on and the Z
homing method changing are the same commit.

---

## 1. Flash Klipper to the Nitehawk

On the Pi:

```bash
cd ~/klipper && make menuconfig
```

Enable extra low-level options, pick **Raspberry Pi RP2040**, and set a
**16KiB bootloader offset** — anything else erases the Katapult bootloader the
board ships with. Then:

```bash
make clean && make
```

```bash
ls /dev/serial/by-id
```

```bash
sudo service klipper stop && make flash FLASH_DEVICE=/dev/serial/by-id/<your id> && sudo service klipper start
```

## 2. Paste the serial path into `nitehawk.cfg`

The `[mcu nhk] serial:` line is a placeholder ending in `REPLACE_ME`. Replace it
with the real `usb-Klipper_rp2040_*-if00` path from the `ls` above.

## 3. Wiring — the PZ goes on the IO Port pads

From LDO's published pinout, the 2.54 mm **IO Port** pad header carries:

```
GND | 3V3 | FS (gpio3) | SU (gpio2)
```

That is the only 3.3 V on the board, and it happens to sit on the same header as
two free GPIOs — so power and signal both come from one place:

| PZ wire | Nitehawk |
|---|---|
| GND (brown) | IO Port `GND` |
| PWR (red) | IO Port `3V3` |
| Trigger (orange) | IO Port `FS` = `gpio3` |

The other three wires on the PZ's 8-pin connector (RX, TX, UPDI, SCL, SDA) are
for firmware updates and configuration — not needed for normal probing.

**Why not the connectorised ports.** Every one of them would power the PZ at the
wrong voltage:

| Port | Pins |
|---|---|
| Neopixel (fan adapter) | `5V / GND / DATA` |
| XY Endstop, JST-XH 4P | `GND / X gpio13 / Y gpio12 / 5V` |
| PROBE, JST-XH 3P | `GND / ABL gpio10 / 24V` |

The PZ's Trigger idles at whatever it is powered from, and RP2040 GPIO is **not**
5 V tolerant. Feeding it from a 5 V pin means 5 V into a 3.3 V input, which needs
a divider or a level shifter to be safe. The `3V3` pad removes the problem
entirely.

`gpio2` (`SU`) is the spare if `gpio3` is awkward. `gpio13` also works as a
trigger input if you prefer the endstop connector — but take **power** from the
`3V3` pad either way.

The IO Port is bare 2.54 mm pads, so this needs a soldered pigtail rather than a
plug. That is the only downside, and it beats a splitter plus level shifting.

**X/Y endstops stay on the mainboard** (`PB14` / `PB13`). `nitehawk.cfg`
deliberately does not override them.

## 4. Enable the toolhead

In `printer.cfg`, uncomment the last line of the Toolhead section:

```
[include nitehawk.cfg]
```

## 5. Switch Z homing to the probe

Still in `printer.cfg`, in `[stepper_z]`:

- delete `endstop_pin: ^PA0`
- delete `position_endstop: 4.265`
- add `endstop_pin: probe:z_virtual_endstop`

Then delete these two lines from the autosave block at the bottom, or Klipper
will reject them as invalid for a virtual endstop:

```
#*# [stepper_z]
#*# position_endstop = 4.265
```

And add a safe Z homing position, since Z now homes by touching the bed:

```
[safe_z_home]
home_xy_position: 150, 150
speed: 100
z_hop: 10
z_hop_speed: 10
```

## 6. First power-on, in this order

1. `RESTART`. Klipper should come up with both MCUs. If it cannot find `nhk`,
   the serial path in step 2 is wrong.
2. **Polarity check, before homing anything.** With the nozzle in mid-air:
   `QUERY_PROBE` must report `open`. Tap the nozzle by hand: it must report
   `TRIGGERED`. If they are backwards, remove the `!` from the probe pin in
   `nitehawk.cfg`.
3. Check temperatures read sanely at room temperature. A wildly wrong hotend
   reading means either `pullup_resistor: 2200` was lost (the Nitehawk's TH0 uses
   2.2k, not the usual 4.7k) or the Revo thermistor is not the Semitec 104NT the
   config assumes.
4. `G28 X Y` first. Only then `G28 Z`, with a finger near the emergency stop.

## 7. Calibrate, in this order

| | |
|---|---|
| `PROBE_CALIBRATE` | Sets `z_offset`. Starts at 0 — it is a nozzle probe, so the offset is squish, not standoff |
| `PID_CALIBRATE HEATER=extruder TARGET=245` | The old PID (21.270 / 1.818 / 62.218) was tuned against a PT100 in a different hotend and is meaningless now |
| Rotation distance | The extruder has been off the machine; re-run the 100mm test |
| `Z_TILT_ADJUST` | |
| `BED_MESH_CALIBRATE` | The saved mesh is a stale 4×3 from the Klicky era — see below |
| `SHAPER_CALIBRATE` | Now possible without bolting anything on; the ADXL345 is onboard |

## 8. Widen the bed mesh

`[bed_mesh]` in `printer.cfg` is currently:

```
mesh_min: 35, 25
mesh_max: 290, 278
probe_count: 5, 5
```

Those inset values existed to keep **Klicky's** offset probe on the bed. The PZ
probes with the nozzle, so `x_offset` and `y_offset` are both 0 and the mesh can
run much closer to the bed edges. Worth revisiting once the probe is trusted.

## Not included, but available

LDO ship a `tacho_macros.cfg` with a `PREFLIGHT_CHECK` macro that briefly spins
the part fan and verifies the tachometer signal. It only helps if your fans are
the 3-pin tacho type; the tachometer lines in `nitehawk.cfg` are commented out
for the same reason. Grab it from
[MotorDynamicsLab/Nitehawk-SB](https://github.com/MotorDynamicsLab/Nitehawk-SB)
if you want it.

## Rolling back

`archive/` holds the SB2209 and SB2240 configs with their CAN UUIDs, and the
Klicky macros and dock coordinates. Nothing was deleted.
