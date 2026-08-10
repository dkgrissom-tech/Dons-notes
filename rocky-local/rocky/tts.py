"""
STEP 3 — Text to speech. Two interchangeable backends.

    TTS_BACKEND=piper        (default) 100% local, nothing leaves the machine
    TTS_BACKEND=elevenlabs   cloud, better voice — sends TEXT to ElevenLabs

Note on ElevenLabs and privacy: your microphone audio still never leaves the
machine in either mode, because STT is always local. But in elevenlabs mode
the *reply text* is sent to their API to be voiced. Pick accordingly.

Self-test:
    python -m rocky.tts
    python -m rocky.tts "custom sentence to speak"
"""
from __future__ import annotations

import io
import os
import subprocess
import sys
import tempfile
import threading

from .config import CFG

_play_lock = threading.Lock()


# --------------------------------------------------------------- playback
def play_wav_bytes(data: bytes):
    import numpy as np
    import soundfile as sf
    import sounddevice as sd
    audio, sr = sf.read(io.BytesIO(data), dtype="float32", always_2d=False)
    with _play_lock:
        sd.play(audio, sr, device=CFG.output_device)
        sd.wait()


def play_file(path: str):
    with open(path, "rb") as f:
        play_wav_bytes(f.read())


# ------------------------------------------------------------------ piper
def ensure_piper_voice() -> str:
    """Download the voice on first use. Returns the voice name."""
    voice = CFG.piper_voice
    vdir = CFG.models_dir / "piper"
    vdir.mkdir(parents=True, exist_ok=True)
    onnx = vdir / f"{voice}.onnx"
    if not onnx.exists():
        print(f"[tts] downloading piper voice {voice} (~60 MB, one time)...")
        subprocess.run(
            [sys.executable, "-m", "piper.download_voices", voice,
             "--data-dir", str(vdir)],
            check=True,
        )
    return voice


def speak_piper(text: str):
    voice = ensure_piper_voice()
    vdir = CFG.models_dir / "piper"
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        out = tf.name
    try:
        subprocess.run(
            [sys.executable, "-m", "piper",
             "-m", voice, "--data-dir", str(vdir),
             "-f", out, "--", text],
            check=True, capture_output=True,
        )
        play_file(out)
    finally:
        try:
            os.unlink(out)
        except OSError:
            pass


# ------------------------------------------------------------- elevenlabs
def speak_elevenlabs(text: str):
    import requests
    key = CFG.elevenlabs_key
    if not key:
        print("[tts] ELEVENLABS_API_KEY not set — falling back to piper")
        return speak_piper(text)
    r = requests.post(
        f"https://api.elevenlabs.io/v1/text-to-speech/{CFG.elevenlabs_voice}",
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        json={
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
        },
        timeout=30,
    )
    if r.status_code != 200:
        print(f"[tts] elevenlabs {r.status_code}: {r.text[:200]} — falling back to piper")
        return speak_piper(text)
    play_wav_bytes(r.content)


# -------------------------------------------------------------- dispatch
def speak(text: str):
    text = (text or "").strip()
    if not text:
        return
    # Strip markdown so the voice doesn't read asterisks and backticks aloud.
    for ch in ("**", "*", "`", "#", "_"):
        text = text.replace(ch, "")
    if len(text) > CFG.max_speak_chars:
        text = text[: CFG.max_speak_chars].rsplit(".", 1)[0] + "."
    try:
        if CFG.tts_backend == "elevenlabs":
            speak_elevenlabs(text)
        else:
            speak_piper(text)
    except Exception as e:
        print(f"[tts] failed: {type(e).__name__}: {e}")


if __name__ == "__main__":
    msg = sys.argv[1] if len(sys.argv) > 1 else \
        "Rocky is online. Speech to text and text to speech are both running locally."
    print(f"[tts] backend={CFG.tts_backend}")
    speak(msg)
    print("[tts] done — if you heard that, step 3 passes.")
