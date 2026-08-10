"""Central config. Everything is overridable from .env or the environment."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

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

    # --- push to talk ---
    hotkey: str = os.environ.get("HOTKEY", "ctrl_r")
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

    models_dir: Path = ROOT / "models"


CFG = Config()
CFG.models_dir.mkdir(exist_ok=True)
