#!/usr/bin/env python3
# Kills a Rails suite run whose log has not grown for STALL seconds (a crashed
# parallel worker leaves the suite waiting forever). Records the kill.
import os, time, glob, signal
RUNS = os.path.expanduser("~/src/runs")
STALL = int(os.environ.get("STALL", "300"))

def timeouts():
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            if open(f"/proc/{pid}/comm").read().strip() != "timeout":
                continue
            cwd = os.readlink(f"/proc/{pid}/cwd")
            env = dict(kv.split("=", 1) for kv in open(f"/proc/{pid}/environ").read().split("\0") if "=" in kv)
        except OSError:
            continue
        yield int(pid), cwd, env

while True:
    for pid, cwd, env in timeouts():
        label = "zjit" if "--zjit" in env.get("RUBYOPT", "") else ("master" if "rubies/master" in env.get("PATH", "") else "r409")
        logs = sorted(glob.glob(f"{RUNS}/{label}/*.log"), key=os.path.getmtime)
        if not logs:
            continue
        log = logs[-1]
        idle = time.time() - os.path.getmtime(log)
        if idle > STALL:
            with open(f"{RUNS}/{label}/watchdog.txt", "a") as f:
                f.write(f"{time.strftime('%H:%M:%S')} killed {os.path.basename(log)} cwd={cwd} idle={int(idle)}s\n")
            os.kill(pid, signal.SIGTERM)
    time.sleep(30)
