# archive

Configs for hardware that is no longer on the machine. Kept because they hold
real tuning and wiring data, and because a CAN toolboard may come back one day.
Nothing in here is included by `printer.cfg` — these files are inert.

| | |
|---|---|
| `sb2209.cfg` | BTT SB2209 CAN toolboard. `canbus_uuid: 4d0edcd66a84` |
| `sb2240.cfg` | BTT SB2240 CAN toolboard. `canbus_uuid: 647ea64f6d35`. Also carries a commented `[extruder]` with `rotation_distance: 21.83`, an ATC Semitec 104NT block, and PID `21.527 / 1.063 / 108.982` |
| `klicky_probe/` | Klicky dock-mounted magnetic probe. Dock at X 31.2, Y 299.2; `z_endstop` at 168.5, 300 |

Replaced by the LDO Nitehawk-SB (USB, RP2040) and an E3D Revo PZ Probe — see
`../nitehawk.cfg`. The PZ probes with the nozzle itself, so there is no dock and
no probe X/Y offset, which is what retired Klicky.
