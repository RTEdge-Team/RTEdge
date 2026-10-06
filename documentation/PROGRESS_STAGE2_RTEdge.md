# RTEdge — Stage 2 Progress Record

## Project

**Project Name:** RTEdge — Intelligent Battery Remaining-Time Estimation
**Current Stage:** Stage 2 — Vehicle-aware hardware-in-the-loop (HIL) dataset and model
**Status:** Vehicle model and load-profile generation complete; rig procurement and data campaign pending

---

# 1. Why Stage 2

Stage 1 (NASA RW3) showed that battery-only inputs limit accuracy:

* Final Random Forest: test MAE 393.66 s, R² 0.54; linear regression MAE 426.90 s, R² 0.47.
* Hyperparameter tuning changed the error by less than 0.6 %.
* Error exceeds 1,600 s when more than an hour of runtime remains.
* Temperature was the strongest correlate of runtime (−0.67) but 68 % of its samples were invalid.

The NASA current profiles are random and not linked to any vehicle, so they cannot show how
gradient, speed or payload affect runtime. Stage 2 generates data in which each of these factors
is controlled and recorded.

# 2. Method

```text
Test condition (speed trace, gradient profile, payload)
        ↓
Road-load model of the Ather 450X (Simulink, 1 s step)
        ↓
Pack power  → regen removed, ÷ driveline efficiency, limited to 6.4 kW
        ↓
Per-cell power  = P_pack / (Ns · Np,eq)          → load profile CSV
        ↓
Raspberry Pi 5:  I_cmd = P_cell / V_measured  (every second)
        ↓
ATORCH DL24P electronic load on an LG INR18650MJ1 cell
        ↓
1 Hz log: V, I, Ah, Wh, T_cell, T_amb + vehicle state
        ↓
Vehicle-aware runtime model
```

## Equations

```text
F      = m·a + m·g·Crr·cosθ + m·g·sinθ + ½·ρ·CdA·v²,   θ = atan(G/100)
P_pack = min( max(F·v, 0) / η , 6.4 kW )
P_cell = P_pack / (Ns · Np,eq),   Ns = 14,   Np,eq = 68.5 Ah / 3.40 Ah = 20.15
I_cmd  = P_cell / V_meas          (clamped to 0.2–8 A)
```

Ns is the number of cells in series in the pack; Np,eq is the equivalent number in parallel.
Dividing by their product gives the bench cell the same power share and C-rate as every cell in
the real pack. Power, not current, is transferred so that the current rises as the cell voltage
falls, exactly as in the vehicle.

## Parameters (`matlab/06_phase2_hil_profiles/phase2_config.m`)

| Parameter | Value | Source |
|---|---|---|
| Vehicle | Ather 450X 3.5 kWh, kerb 111.6 kg, 6.4 kW peak, 90 km/h | manufacturer |
| Pack | 51.1 V, 68.5 Ah, 14S | manufacturer / derived |
| CdA, Crr, η | 0.54 m², 0.015, 0.85 | assumed |
| Bench cell | LG INR18650MJ1, 3.40 Ah min, 3.635 V nominal, 10 A max | datasheet |
| End of discharge | 3.20 V (kept from Stage 1) | decision |

## Model check

Force calculation matches a hand calculation exactly. Over the Indian Driving Cycle (IDC) the
model gives a mean pack power of 474 W (peak 2,062 W), i.e. 21.7 Wh/km and about 162 km from
3.5 kWh, against the certified 161 km.

Note: the IDC trace in `make_drive_cycle.m` is a reconstruction that reproduces the published
statistics (108 s, max 42 km/h, average 21.9 km/h); replace it with the certified table when
obtained.

# 3. Test matrix

| Block | Conditions | Factor varied | Time per run (h) |
|---|---|---|---|
| A | IDC, flat, rider 75 kg (3 repeats) | none (baseline) | 7.3 |
| B | IDC at +2 %, +4 %, +6 % | gradient | 5.1 / 3.7 / 2.9 |
| C | cruise 35, 45, 60 km/h | speed | 5.2 / 3.0 / 1.5 |
| D | IDC, rolling terrain ±3 %, ±5 % | terrain | 7.3 / 6.8 |
| E | IDC, rider 60, 90, 120 kg | payload | 7.7 / 7.0 / 6.4 |
| F | 10 mixed commutes, random terrain, 60–120 kg | combined (test set) | 4.5–5.4 |
| **Total** | **24 discharges, 22 conditions** | | **≈127 h** |

≈4.6 lakh one-second records, equivalent to ≈3,350 km of riding. Constant downhill runs are
excluded because the demand would fall below the 0.2 A minimum of the load.

# 4. Evaluation plan

* Baselines: Coulomb counting; Random Forest with battery-only inputs (as Stage 1).
* Proposed: Random Forest with battery + temperature + vehicle-state inputs (causal features only).
* Split by whole discharge (leave-one-discharge-out, all repeats of a condition withheld);
  train on Blocks A–E, test on Block F.
* Metrics: MAE, RMSE, R²; two-sided sign test over 24 runs (≥18 improvements for p < 0.05).

# 5. Status

| Item | Status |
|---|---|
| Simulink vehicle model (`build_phase2_model.m`) | Done |
| Drive-cycle and gradient generator (`make_drive_cycle.m`) | Done |
| Batch profile generation + manifest (`run_phase2_batch.m`) | Done |
| Smoke test (`phase2_smoke_test.m`) | Written |
| Pi runner with safety limits (`pi/hil_runner.py`) | Written; awaiting hardware for `--selftest` |
| Bench cell changed from Panasonic NCR18650GA to LG INR18650MJ1 | Done (config + runner) |
| Procurement and rig assembly | Pending |
| Cell characterisation (capacity, internal resistance) | Pending |
| Data campaign (24 discharges) | Pending |
| Vehicle-aware model and factor analysis | Pending |

# 6. Next: Stage 3

Instrumented electric scooter (pack V/I, GPS speed and gradient, temperature) on defined routes
in Prayagraj — level roads, flyovers, different payloads — to check that bench findings hold on
the road.
