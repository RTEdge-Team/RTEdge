# Phase 2 HIL rig — hardware

Full parts list with costs: `bill_of_materials.csv` (total ₹8,405; the Raspberry Pi 5 is
available in the department).

## Wiring

```text
 Cell (+) ──10 A fuse──XT30──► DL24P load (+)          power path, 18 AWG silicone wire
 Cell (−) ─────────────XT30──► DL24P load (−)
 Cell (+)/(−) ─── separate thin sense pair ──► DL24P sense terminals (4-wire voltage)
 DL24P USB ───────────────────► Raspberry Pi 5 USB
 DS18B20 × 2 (CELL taped to the cell, AMB in free air)
     VDD → Pi 3.3 V (pin 1)   GND → Pi GND (pin 6)   DATA → GPIO4 (pin 7), 4.7 kΩ pull-up to 3.3 V
 Second cell: TP4056 (1 A CC-CV to 4.2 V) on the 5 V adapter, recharging while the first is tested
```

The cell under test sits in its holder inside the fire-resistant bag for every run.

## Safety limits (enforced in `pi/hil_runner.py`)

| Check | Limit | Action |
|---|---|---|
| Start voltage | < 4.00 V | run refused (cell not freshly charged) |
| Over-voltage | > 4.30 V | abort (charger still connected / miswired) |
| End of discharge | ≤ 3.20 V for 3 consecutive readings | run ends normally |
| Current | 8 A software, 8.5 A load protection, 10 A fuse | clamp / trip |
| Cell surface temperature | > 55 °C | abort |
| Any communication fault | 5 failed writes | load switched off |

## Procedure per run

1. Charge the cell to 4.2 V (TP4056), rest 30 min.
2. Check the cell and ambient sensors read sensibly (`python hil_runner.py --list-sensors`).
3. Start the profile; the runner stops at 3.20 V and writes a JSON summary
   (delivered capacity, energy, end reason).
4. Swap cells and repeat. Each cell sees fewer than 30 cycles in the whole campaign
   (rated life ≈ 400 cycles).

Before the first run: measure each cell's reference capacity and internal resistance, put them in
`matlab/06_phase2_hil_profiles/phase2_config.m`, and cross-check the load's readings against a
digital multimeter.
