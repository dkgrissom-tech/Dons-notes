#!/usr/bin/env python3
"""
STEP 1 — Machine check. Installs nothing, changes nothing, writes nothing.

Run this first:
    python preflight.py

It reports what you already have, what your hardware can run, and which
STT model size to pick. Read the verdict at the bottom before installing.
"""
import json
import os
import platform
import shutil
import subprocess
import sys

OK, WARN, BAD = "  OK  ", " WARN ", " MISS "
report = {}


def line(tag, label, detail=""):
    print(f"[{tag}] {label:<26} {detail}")


def run(cmd):
    """Run a command, return stdout or None. Never raises."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return p.stdout.strip() if p.returncode == 0 else None
    except Exception:
        return None


def have(binary):
    return shutil.which(binary) is not None


print("\n" + "=" * 62)
print("  ROCKY LOCAL — PREFLIGHT")
print("=" * 62 + "\n")

# ---------------------------------------------------------------- system
print("SYSTEM\n" + "-" * 62)
osname = platform.system()
report["os"] = osname
line(OK, "OS", f"{osname} {platform.release()} ({platform.machine()})")

pyver = sys.version_info
report["python"] = f"{pyver.major}.{pyver.minor}.{pyver.micro}"
if pyver >= (3, 10):
    line(OK, "Python", report["python"])
else:
    line(BAD, "Python", f"{report['python']} — need 3.10+ (3.12 recommended)")

in_venv = sys.prefix != sys.base_prefix
report["venv"] = in_venv
line(OK if in_venv else WARN, "Virtual env",
     sys.prefix if in_venv else "not active — strongly recommended")

# RAM
ram_gb = None
try:
    if osname == "Linux":
        with open("/proc/meminfo") as f:
            for l in f:
                if l.startswith("MemTotal"):
                    ram_gb = int(l.split()[1]) / 1024 / 1024
                    break
    elif osname == "Darwin":
        out = run(["sysctl", "-n", "hw.memsize"])
        ram_gb = int(out) / 1024**3 if out else None
    elif osname == "Windows":
        out = run(["powershell", "-NoProfile", "-Command",
                   "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"])
        ram_gb = int(out) / 1024**3 if out else None
except Exception:
    pass
report["ram_gb"] = round(ram_gb, 1) if ram_gb else None
if ram_gb:
    line(OK if ram_gb >= 8 else WARN, "RAM", f"{ram_gb:.1f} GB")
else:
    line(WARN, "RAM", "could not detect")

free_gb = shutil.disk_usage(os.path.expanduser("~")).free / 1024**3
report["disk_free_gb"] = round(free_gb, 1)
line(OK if free_gb >= 10 else WARN, "Free disk", f"{free_gb:.1f} GB  (need ~5 GB)")

# ------------------------------------------------------------------- gpu
print("\nACCELERATION\n" + "-" * 62)
gpu = None
nv = run(["nvidia-smi", "--query-gpu=name,memory.total,driver_version",
          "--format=csv,noheader"])
if nv:
    gpu = nv.splitlines()[0]
    line(OK, "NVIDIA GPU", gpu)
    cuda_hdr = run(["nvidia-smi"])
    if cuda_hdr and "CUDA Version:" in cuda_hdr:
        cv = cuda_hdr.split("CUDA Version:")[1].split()[0]
        report["cuda"] = cv
        line(OK, "CUDA (driver max)", cv)
elif osname == "Darwin" and platform.machine() == "arm64":
    gpu = "Apple Silicon"
    line(OK, "Apple Silicon", "CoreML / Metal available")
else:
    line(WARN, "GPU", "none detected — CPU inference (slower but fine)")
report["gpu"] = gpu

# -------------------------------------------------------------- existing
print("\nALREADY INSTALLED\n" + "-" * 62)
for label, binary in [("ffmpeg", "ffmpeg"), ("git", "git"), ("node", "node"),
                      ("claude (Claude Code)", "claude"), ("piper", "piper"),
                      ("ffplay", "ffplay")]:
    present = have(binary)
    report[binary] = present
    ver = ""
    if present and binary == "claude":
        ver = run(["claude", "--version"]) or ""
    elif present and binary == "node":
        ver = run(["node", "--version"]) or ""
    line(OK if present else BAD, label, ver or ("found" if present else "not found"))

for mod in ["faster_whisper", "piper", "sounddevice", "soundfile",
            "numpy"]:
    try:
        __import__(mod)
        report[f"py:{mod}"] = True
        line(OK, f"python: {mod}", "importable")
    except Exception:
        report[f"py:{mod}"] = False
        line(BAD, f"python: {mod}", "not installed")

# ------------------------------------------------------------------ mics
print("\nAUDIO INPUT\n" + "-" * 62)
mics = []
try:
    import sounddevice as sd
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0:
            mics.append((i, d["name"], int(d["default_samplerate"])))
    default_in = sd.default.device[0]
    for i, name, sr in mics:
        mark = " <- default" if i == default_in else ""
        line(OK, f"input #{i}", f"{name[:38]} @ {sr} Hz{mark}")
    if not mics:
        line(BAD, "microphones", "none found")
except Exception as e:
    line(WARN, "microphones", f"cannot enumerate until sounddevice installed ({type(e).__name__})")
report["mics"] = len(mics)

# --------------------------------------------------------------- verdict
print("\n" + "=" * 62)
print("  VERDICT")
print("=" * 62)

if gpu and "Apple" not in str(gpu):
    vram = 0
    try:
        vram = int(gpu.split(",")[1].strip().split()[0])
    except Exception:
        pass
    if vram >= 8000:
        stt = ("large-v3", "cuda", "float16", "~1.5 GB VRAM, best accuracy")
    elif vram >= 4000:
        stt = ("medium.en", "cuda", "float16", "~800 MB VRAM")
    else:
        stt = ("small.en", "cuda", "int8_float16", "low VRAM")
elif gpu == "Apple Silicon":
    stt = ("medium.en", "cpu", "int8", "Apple Silicon CPU is fast enough")
elif ram_gb and ram_gb >= 16:
    stt = ("small.en", "cpu", "int8", "CPU-only, ~2s latency on short clips")
else:
    stt = ("base.en", "cpu", "int8", "CPU-only, low RAM, fastest")

report["recommended_stt"] = {"model": stt[0], "device": stt[1], "compute_type": stt[2]}

print(f"""
  Recommended STT : {stt[0]}  on {stt[1]}  ({stt[2]})
                    {stt[3]}
  Recommended TTS : piper / en_US-lessac-medium  (~60 MB, runs anywhere)

  Put these in your .env:
      STT_MODEL={stt[0]}
      STT_DEVICE={stt[1]}
      STT_COMPUTE={stt[2]}
""")

blockers = []
if pyver < (3, 10):
    blockers.append("Python 3.10+ required")
if not report.get("claude"):
    blockers.append("Claude Code CLI not found  ->  npm i -g @anthropic-ai/claude-code")
if report["mics"] == 0 and report.get("py:sounddevice"):
    blockers.append("No microphone detected")
if free_gb < 5:
    blockers.append("Less than 5 GB free disk")

if blockers:
    print("  BLOCKERS — fix these first:")
    for b in blockers:
        print(f"    - {b}")
else:
    print("  No blockers. Clear to proceed to STEP 2.")

with open("preflight.json", "w") as f:
    json.dump(report, f, indent=2)
print("\n  Full report written to preflight.json")
print("=" * 62 + "\n")
