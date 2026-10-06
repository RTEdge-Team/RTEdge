#!/usr/bin/env python3
"""hil_runner.py - Phase 2 hardware-in-the-loop runner for the ATORCH DL24P.

Plays one Simulink load-profile CSV into a single cell, one second at a time,
and logs what the cell actually did.

    python hil_runner.py --list-sensors
    python hil_runner.py --selftest              # Week 1, with any charged cell
    python hil_runner.py profiles/A1_idc_flat.csv --cell MJ1-01 --note "day 1 overnight"

Every second:
    1. read the load: voltage (4-wire), current, power, MOSFET temperature
    2. look up P_cell_W for this second of the profile
    3. I_cmd = P_cell_W / V_measured   (clamped to [I_FLOOR, I_MAX]; 0 A when P = 0)
    4. send I_cmd to the load
    5. write one CSV row, measured and commanded side by side

Facts about the DL24P this script is built around (source: sophusand/atorch-dl24p-python,
PROTOCOL.md, reverse-engineered against firmware V1.1.0, and nevetssf/aTorch-DL24P):
  * Current units talk USB-HID (VID 0483, PID 5750). No serial port.
  * The load's own cut-off voltage is stored but NOT enforced. This script enforces V_END.
  * The load's time limit IS enforced. This script uses it as a dead-man switch.
  * The current ramps softly: ~2 s to reach 90 % of a step. Total charge is unaffected, but
    second-by-second current lags the command. ALWAYS train on I_meas, never on I_cmd.
  * The library is tested on Windows and macOS, NOT on Linux. Run --selftest first.
"""
import argparse
import csv
import glob
import json
import os
import signal
import sys
import threading
import time
from datetime import datetime

import dl24p

# ============================================================== CONFIG ===
V_END = 3.20            # V, discharge endpoint. MUST match phase2_config.m C.cell.V_end
ENDPOINT_SAMPLES = 3    # consecutive samples <= V_END before stopping (rejects noise).
                        # The runtime label is the time of the FIRST of them.
V_START_MIN = 4.00      # V, below this the cell was not freshly charged -> refuse
V_ABS_MAX = 4.30        # V, above this something is miswired (charger still on?) -> abort
I_FLOOR = 0.20          # A, DL24P spec minimum. --selftest checks what it really does.
I_MAX = 8.0             # A, hard ceiling (MJ1 is rated 10 A continuous)
OVER_CURRENT = 8.5      # A, programmed into the load's own protection
T_CELL_MAX = 55.0       # degC, abort (MJ1 discharge limit is 60 degC)
ZERO_MODE = "setpoint"  # P_cell = 0 (stopped/coasting/braking): "setpoint" sends 0 A,
                        # "floor" sends I_FLOOR. Pick after --selftest step 3.
DEADMAN_MODE = "off"    # "elapsed" | "from_now" | "off". Pick after --selftest step 4.
DEADMAN_MARGIN_MIN = 3  # minutes of slack the dead-man allows
DEADMAN_REFRESH_S = 60
MAX_CMD_ERRORS = 5      # consecutive failed set-point writes before a safe abort
FSYNC_EVERY = 10        # rows between forced writes to the SD card

# DS18B20 IDs, from --list-sensors. Tape "CELL" to the cell, leave "AMB" in free air.
SENSORS = {"CELL": None, "AMB": None}   # e.g. {"CELL": "28-3c01d0751abc", "AMB": "28-..."}

LOG_DIR = "logs"
PROFILE_COLS = ["velocity_kmh", "accel_mps2", "grade_pct", "regen_flag", "power_limited_flag"]
# =========================================================================

W1_ROOT = "/sys/bus/w1/devices"
_stop = threading.Event()


def _on_signal(signum, _frame):
    print(f"\nSignal {signum} received - stopping safely.")
    _stop.set()


# ------------------------------------------------------------- sensors ---
def list_sensors():
    return sorted(os.path.basename(p) for p in glob.glob(os.path.join(W1_ROOT, "28-*")))


def read_ds18b20(sensor_id):
    """Temperature in degC, or None. Takes ~750 ms - never call from the 1 Hz loop."""
    try:
        with open(os.path.join(W1_ROOT, sensor_id, "w1_slave")) as f:
            lines = f.read().strip().splitlines()
        if len(lines) < 2 or not lines[0].endswith("YES"):
            return None                      # CRC failure
        t = int(lines[1].split("t=")[1]) / 1000.0
        return None if t == 85.0 else t      # 85.000 is the sensor's power-on reset value
    except (OSError, IndexError, ValueError):
        return None


class TempReader(threading.Thread):
    """Reads the DS18B20s continuously in the background; the main loop takes the latest."""

    def __init__(self, sensors):
        super().__init__(daemon=True)
        self.sensors = {k: v for k, v in sensors.items() if v}
        self.latest = {k: None for k in sensors}
        self.stamp = {k: 0.0 for k in sensors}

    def run(self):
        while not _stop.is_set():
            for role, sid in self.sensors.items():
                t = read_ds18b20(sid)
                if t is not None:
                    self.latest[role] = t
                    self.stamp[role] = time.monotonic()
            time.sleep(0.2)

    def get(self, role, max_age=10.0):
        if role not in self.latest or time.monotonic() - self.stamp[role] > max_age:
            return None                      # stale is reported as missing, not reused
        return self.latest[role]


# ------------------------------------------------------------- profile ---
def load_profile(path):
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows.append((float(r["P_cell_W"]), [r[c] for c in PROFILE_COLS]))
    if not rows:
        raise SystemExit(f"{path}: profile is empty")
    return rows


# ------------------------------------------------------------ dead-man ---
def arm_deadman(load, elapsed_s):
    """Keep the load's enforced time limit just ahead of 'now', so a crashed or frozen
    Pi leaves the load drawing current for at most DEADMAN_MARGIN_MIN more minutes.
    Which formula is right depends on how the firmware counts - see --selftest step 4."""
    if DEADMAN_MODE == "off":
        return
    total = DEADMAN_MARGIN_MIN
    if DEADMAN_MODE == "elapsed":
        total += int(elapsed_s // 60)
    h, m = divmod(total, 60)
    load.set_time_limit(min(h, 99), m)


# --------------------------------------------------------------- run ---
def run(profile_path, cell_id, note, assume_yes):
    profile = load_profile(profile_path)
    mean_p = sum(p for p, _ in profile) / len(profile)
    est_h = 3.40 * 3.635 / mean_p if mean_p > 0 else float("nan")

    temps = TempReader(SENSORS)
    temps.start()

    os.makedirs(LOG_DIR, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = f"{stamp}_{cell_id}_{os.path.splitext(os.path.basename(profile_path))[0]}"
    csv_path = os.path.join(LOG_DIR, base + ".csv")
    meta_path = os.path.join(LOG_DIR, base + ".json")

    meta = {"profile": os.path.abspath(profile_path), "cell_id": cell_id, "note": note,
            "V_end": V_END, "endpoint_samples": ENDPOINT_SAMPLES, "I_floor": I_FLOOR,
            "zero_mode": ZERO_MODE, "deadman_mode": DEADMAN_MODE,
            "sensors": SENSORS, "profile_rows": len(profile), "est_discharge_h": round(est_h, 2)}

    with dl24p.DL24P() as load:
        # ---- pre-flight: leave the load in a known, safe state first -------
        load.off()
        meta["device"] = load.product
        load.set_mode("CC")
        load.set_value(I_FLOOR)
        load.set_over_current(OVER_CURRENT)
        load.set_time_limit(0, 0)

        time.sleep(2.0)                                   # let the first temperatures arrive
        m0 = load.read()
        t_cell0, t_amb0 = temps.get("CELL"), temps.get("AMB")
        print(f"Device : {load.product}")
        print(f"Profile: {profile_path}  ({len(profile)} s, est. discharge {est_h:.1f} h)")
        print(f"Cell   : {cell_id}   V = {m0.voltage:.3f} V   "
              f"T_cell = {t_cell0}   T_amb = {t_amb0}")

        if m0.voltage > V_ABS_MAX:
            raise SystemExit(f"V = {m0.voltage:.3f} V is above {V_ABS_MAX} V - check wiring.")
        if m0.voltage < V_START_MIN:
            raise SystemExit(f"V = {m0.voltage:.3f} V is below {V_START_MIN} V - "
                             "charge the cell and rest it 30 min first.")
        if any(v is None for v in SENSORS.values()):
            print("WARNING: SENSORS not configured - temperature channels will be empty.")
        if not assume_yes and input("Start discharge? [y/N] ").strip().lower() != "y":
            raise SystemExit("Aborted before start.")

        meta.update(start_time=datetime.now().isoformat(timespec="seconds"),
                    V_start=m0.voltage, T_cell_start=t_cell0, T_amb_start=t_amb0)

        f = open(csv_path, "w", newline="")
        w = csv.writer(f)
        w.writerow(["wall_time", "t_s", "idx", "P_cell_cmd_W", "I_cmd_A", "zero_flag",
                    "floor_flag", "V_meas_V", "I_meas_A", "P_meas_W", "capacity_mAh",
                    "energy_Wh", "T_cell_C", "T_amb_C", "T_mos_C", "load_on"]
                   + PROFILE_COLS + ["late_ms"])

        reason, first_below_t, below = "unknown", None, 0
        cmd_errors, last_set, rows = 0, None, 0
        last_deadman = -1e9
        cap0, en0 = m0.capacity_mah, m0.energy_wh

        t0 = time.monotonic()
        try:
            load.set_value(I_FLOOR)
            load.on()                                   # verified: waits until it holds
            t0 = time.monotonic()
            arm_deadman(load, 0)
            last_deadman = 0.0
            k = 0
            while not _stop.is_set():
                # ---- wall-clock scheduling: the profile never stretches ------
                target = t0 + k
                delay = target - time.monotonic()
                if delay > 0:
                    time.sleep(delay)
                now = time.monotonic()
                t_run = now - t0
                idx = int(round(t_run))
                late_ms = int((now - (t0 + idx)) * 1000)
                if idx >= len(profile):
                    reason = "profile_exhausted"
                    break

                m = load.read()
                v = m.voltage
                t_cell, t_amb = temps.get("CELL"), temps.get("AMB")

                # ---- safety stops ------------------------------------------
                if not m.output_on:
                    reason = "load_switched_off"      # time limit or a protection tripped
                    break
                if v > V_ABS_MAX:
                    reason = "overvoltage_abort"
                    break
                if t_cell is not None and t_cell > T_CELL_MAX:
                    reason = "cell_overtemp_abort"
                    break

                # ---- set point for this second -----------------------------
                p_cell, extra = profile[idx]
                zero_flag = floor_flag = 0
                if p_cell <= 0:
                    zero_flag = 1
                    i_cmd = 0.0 if ZERO_MODE == "setpoint" else I_FLOOR
                else:
                    i_cmd = p_cell / v
                    if i_cmd < I_FLOOR:
                        floor_flag, i_cmd = 1, I_FLOOR
                    i_cmd = min(i_cmd, I_MAX)
                i_cmd = round(i_cmd, 3)

                if i_cmd != last_set:                  # skip redundant HID writes
                    try:
                        load.set_value(i_cmd)
                        last_set, cmd_errors = i_cmd, 0
                    except dl24p.DL24PError as e:
                        cmd_errors += 1
                        print(f"[t={t_run:7.0f}s] set-point error {cmd_errors}: {e}")
                        if cmd_errors >= MAX_CMD_ERRORS:
                            reason = "command_error_abort"
                            break

                # ---- log ---------------------------------------------------
                w.writerow([datetime.now().isoformat(timespec="milliseconds"),
                            round(t_run, 3), idx, round(p_cell, 5), i_cmd, zero_flag,
                            floor_flag, v, m.current, m.power,
                            round(m.capacity_mah - cap0, 3), round(m.energy_wh - en0, 5),
                            t_cell, t_amb, m.temp_mos, int(m.output_on)] + extra + [late_ms])
                rows += 1
                f.flush()
                if rows % FSYNC_EVERY == 0:
                    os.fsync(f.fileno())

                # ---- endpoint (loaded voltage, as in Phase 1) --------------
                if v <= V_END:
                    below += 1
                    if below == 1:
                        first_below_t = t_run
                    if below >= ENDPOINT_SAMPLES:
                        reason = "endpoint"
                        break
                else:
                    below, first_below_t = 0, None

                if t_run - last_deadman >= DEADMAN_REFRESH_S:
                    try:
                        arm_deadman(load, t_run)
                        last_deadman = t_run
                    except dl24p.DL24PError as e:
                        print(f"[t={t_run:7.0f}s] dead-man refresh failed: {e}")

                if idx % 300 == 0:
                    print(f"[{t_run/3600:5.2f} h] V={v:.3f} I={m.current:.3f}/{i_cmd:.3f} A "
                          f"cap={m.capacity_mah - cap0:7.1f} mAh T_cell={t_cell}")
                k = idx + 1
            else:
                reason = "stopped_by_user"
        finally:
            try:
                load.off()
            except Exception as e:                      # never skip the rest of cleanup
                print(f"!!! COULD NOT SWITCH THE LOAD OFF: {e} - SWITCH IT OFF BY HAND !!!")
            f.flush()
            os.fsync(f.fileno())
            f.close()
            _stop.set()
            try:
                mf = load.read()
                meta.update(V_end_measured=mf.voltage,
                            capacity_mAh=round(mf.capacity_mah - cap0, 2),
                            energy_Wh=round(mf.energy_wh - en0, 4))
            except Exception:
                pass
            meta.update(end_time=datetime.now().isoformat(timespec="seconds"),
                        end_reason=reason, rows=rows,
                        runtime_label_s=round(first_below_t, 1)
                        if reason == "endpoint" else None)
            with open(meta_path, "w") as jf:
                json.dump(meta, jf, indent=2)

    print(f"\nEnd: {reason}   rows: {rows}")
    if reason == "endpoint":
        print(f"Runtime label: {first_below_t:.0f} s ({first_below_t/3600:.2f} h)  "
              f"capacity {meta.get('capacity_mAh')} mAh")
    else:
        print("No valid runtime label for this run - record why in the lab notebook.")
    print(f"Log : {csv_path}\nMeta: {meta_path}")


# ------------------------------------------------------------ selftest ---
def selftest():
    """Week 1 characterisation. Needs a charged cell (>3.6 V) wired as for a real run.
    Takes about 6 minutes and draws well under 0.2 Ah."""
    def sample(load, secs, hz=5):
        out, t_start = [], time.monotonic()
        while time.monotonic() - t_start < secs:
            m = load.read()
            out.append((round(time.monotonic() - t_start, 2), m.voltage, m.current, m.output_on))
            time.sleep(1 / hz)
        return out

    print("DS18B20 sensors found:", list_sensors() or "none (is dtoverlay=w1-gpio enabled?)")
    with dl24p.DL24P() as load:
        load.off()
        print("Device:", load.product)
        m = load.read()
        print(f"Idle: V={m.voltage:.3f} V  I={m.current:.3f} A")
        if not 3.6 <= m.voltage <= V_ABS_MAX:
            raise SystemExit("Connect a charged cell (3.6-4.2 V) before the self-test.")
        load.set_mode("CC")
        load.set_over_current(OVER_CURRENT)
        load.set_time_limit(0, 0)

        print("\n[1] Step response 0.30 A -> 1.00 A (how fast the current follows):")
        load.set_value(0.30)
        load.on()
        sample(load, 3)
        load.set_value(1.00)
        s = sample(load, 5)
        t90 = next((t for t, _, i, _ in s if i >= 0.93), None)
        print(f"    reached 90 % of the step after {t90} s   (library reports ~2 s)")

        print("\n[2] Tracking at 1 Hz, the rate the runner uses:")
        for sp in (0.5, 0.8, 0.3, 1.2, 0.6):
            load.set_value(sp)
            time.sleep(1.0)
            print(f"    commanded {sp:.2f} A -> measured {load.read().current:.3f} A after 1 s")

        print("\n[3] Low set points (decides ZERO_MODE and the real I_FLOOR):")
        for sp in (0.20, 0.15, 0.10, 0.05, 0.0):
            try:
                load.set_value(sp)
                time.sleep(3.0)
                mm = load.read()
                print(f"    set {sp:.2f} A -> measured {mm.current:.3f} A, load_on={mm.output_on}")
            except dl24p.DL24PError as e:
                print(f"    set {sp:.2f} A -> REJECTED: {e}")
        print("    Cross-check two of these with your multimeter in series.")

        print("\n[4] Time-limit semantics (decides DEADMAN_MODE). ~3.5 min, please wait:")
        load.set_value(0.30)
        if not load.is_on:
            load.on()
        t_on = time.monotonic()
        load.set_time_limit(0, 1)
        time.sleep(30)
        load.set_time_limit(0, 2)                     # re-armed at t = 30 s while running
        t_rearm = time.monotonic()
        still_on = load.is_on
        print(f"    load still on after re-arming: {still_on}")
        off_at = None
        while time.monotonic() - t_on < 200:
            if not load.read().output_on:
                off_at = time.monotonic()
                break
            time.sleep(1.0)
        load.off()
        load.set_time_limit(0, 0)
        if off_at is None:
            print("    load never switched itself off -> time limit unusable, keep DEADMAN_MODE='off'")
        else:
            a, b = off_at - t_on, off_at - t_rearm
            print(f"    switched off {a:.0f} s after ON, {b:.0f} s after re-arm")
            if abs(a - 120) < 15:
                print("    -> counts from ON: set DEADMAN_MODE = 'elapsed'")
            elif abs(b - 120) < 15:
                print("    -> counts from when it was set: set DEADMAN_MODE = 'from_now'")
            else:
                print("    -> neither pattern fits; keep DEADMAN_MODE = 'off' and tell me the numbers")
        if not still_on:
            print("    WARNING: re-arming switched the load off - keep DEADMAN_MODE = 'off'")
    print("\nSelf-test complete. Load is off.")


# ---------------------------------------------------------------- main ---
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("profile", nargs="?", help="profile CSV from run_phase2_batch.m")
    ap.add_argument("--cell", default="MJ1-01", help="cell ID written on the cell")
    ap.add_argument("--note", default="", help="free text for the run's metadata")
    ap.add_argument("--yes", action="store_true", help="skip the start confirmation")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--list-sensors", action="store_true")
    a = ap.parse_args()

    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)

    if a.list_sensors:
        ids = list_sensors()
        if not ids:
            print("No DS18B20 found. Enable 1-Wire (dtoverlay=w1-gpio) and check the 4.7 kohm pull-up.")
        for sid in ids:
            print(f"{sid}  {read_ds18b20(sid)} degC")
        print("Warm one probe in your hand to tell CELL from AMB, then fill in SENSORS.")
    elif a.selftest:
        selftest()
    elif a.profile:
        run(a.profile, a.cell, a.note, a.yes)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
