"""Central config. Everything is overridable from .env or the environment."""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Windows consoles often default to a legacy codepage (cp1252) that can't
# encode characters like em dashes or bullets. A print() that hits one of
# those raises UnicodeEncodeError — and if that happens inside a C callback
# (e.g. the sounddevice audio thread), Python silently drops the exception,
# so any code after the failed print() (like queuing captured audio) never
# runs. Force UTF-8 everywhere, regardless of which module is the entry point.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent

# Load .env without a hard dependency on python-dotenv.
_envfile = ROOT / ".env"
if _envfile.exists():
    for raw in _envfile.read_text().splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        k, v = raw.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def _int(name, default):
    try:
        return int(os.environ[name])
    except (KeyError, ValueError):
        return default


def _dev(name):
    """Audio device: blank = system default, digits = index, else substring."""
    v = os.environ.get(name, "").strip()
    if not v:
        return None
    return int(v) if v.lstrip("-").isdigit() else v


@dataclass
class Config:
    # --- speech to text (local, always) ---
    stt_model: str = os.environ.get("STT_MODEL", "small.en")
    stt_device: str = os.environ.get("STT_DEVICE", "cpu")
    stt_compute: str = os.environ.get("STT_COMPUTE", "int8")
    stt_language: str = os.environ.get("STT_LANGUAGE", "en")

    # --- text to speech ---
    tts_backend: str = os.environ.get("TTS_BACKEND", "piper").lower()
    piper_voice: str = os.environ.get("PIPER_VOICE", "en_US-lessac-medium")
    elevenlabs_key: str = os.environ.get("ELEVENLABS_API_KEY", "")
    elevenlabs_voice: str = os.environ.get("ELEVENLABS_VOICE_ID",
                                           "pNInz6obpgDQGcFmaJgB")
    max_speak_chars: int = _int("MAX_SPEAK_CHARS", 900)

    # --- voice activation (no hotkey — the mic itself decides) ---
    vad_threshold: float = float(os.environ.get("VAD_THRESHOLD", "0.02"))
    vad_silence_ms: int = _int("VAD_SILENCE_MS", 800)
    min_hold_ms: int = _int("MIN_HOLD_MS", 250)
    max_record_s: int = _int("MAX_RECORD_S", 60)

    # --- audio devices ---
    input_device: object = field(default_factory=lambda: _dev("INPUT_DEVICE"))
    output_device: object = field(default_factory=lambda: _dev("OUTPUT_DEVICE"))

    # --- claude code bridge ---
    claude_bin: str = os.environ.get("CLAUDE_BIN", "claude")
    claude_cwd: str = os.environ.get("CLAUDE_CWD", str(Path.home()))
    claude_tools: str = os.environ.get(
        "CLAUDE_ALLOWED_TOOLS", "Read,Grep,Glob,Bash,Edit,Write")
    claude_timeout: int = _int("CLAUDE_TIMEOUT", 300)
    persist_session: bool = os.environ.get("PERSIST_SESSION", "1") == "1"
    claude_model: str = os.environ.get("CLAUDE_MODEL", "")
    claude_permission_mode: str = os.environ.get("CLAUDE_PERMISSION_MODE", "")

    models_dir: Path = ROOT / "models"


CFG = Config()
CFG.models_dir.mkdir(exist_ok=True)
