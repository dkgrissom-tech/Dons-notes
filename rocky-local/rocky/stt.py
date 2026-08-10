"""
STEP 2 — Speech to text. Fully local, via faster-whisper (CTranslate2).

Audio never leaves the machine. The model file is downloaded once from
Hugging Face on first run, then it is offline forever after.

Self-test:
    python -m rocky.stt              # record 5s from the mic, transcribe
    python -m rocky.stt some.wav     # transcribe an existing file
"""
from __future__ import annotations

import os
import sys
import time
import wave

import numpy as np

from .config import CFG

SAMPLE_RATE = 16000  # whisper is trained at 16 kHz; do not change

_model = None


def get_model():
    """Load once, keep hot. First call downloads the model (~40 MB - 1.5 GB)."""
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        t = time.time()
        print(f"[stt] loading {CFG.stt_model} on {CFG.stt_device} ({CFG.stt_compute})...")
        _model = WhisperModel(
            CFG.stt_model,
            device=CFG.stt_device,
            compute_type=CFG.stt_compute,
            download_root=str(CFG.models_dir / "whisper"),
        )
        print(f"[stt] ready in {time.time() - t:.1f}s")
    return _model


def transcribe_array(audio: np.ndarray) -> str:
    """audio: float32 mono at 16 kHz, range -1..1."""
    if audio.size == 0:
        return ""
    # Reject near-silence so an accidental key tap doesn't invoke the agent.
    rms = float(np.sqrt(np.mean(audio**2)))
    if rms < 0.004:
        print(f"[stt] rejected: silence (rms={rms:.4f})")
        return ""

    model = get_model()
    t = time.time()
    segments, info = model.transcribe(
        audio,
        language=CFG.stt_language,
        beam_size=5,
        vad_filter=True,                     # strips leading/trailing silence
        vad_parameters={"min_silence_duration_ms": 300},
        condition_on_previous_text=False,    # avoids runaway hallucination loops
    )
    text = " ".join(s.text.strip() for s in segments).strip()
    dur = len(audio) / SAMPLE_RATE
    print(f"[stt] {dur:.1f}s audio -> {time.time() - t:.1f}s decode "
          f"(lang={info.language} p={info.language_probability:.2f})")
    return text


def transcribe_file(path: str) -> str:
    import soundfile as sf
    audio, sr = sf.read(path, dtype="float32", always_2d=False)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    if sr != SAMPLE_RATE:
        # linear resample — good enough for speech
        idx = np.linspace(0, len(audio) - 1, int(len(audio) * SAMPLE_RATE / sr))
        audio = np.interp(idx, np.arange(len(audio)), audio).astype("float32")
    return transcribe_array(audio)


def record_seconds(seconds: float = 5.0) -> np.ndarray:
    import sounddevice as sd
    print(f"[stt] recording {seconds}s — speak now...")
    buf = sd.rec(int(seconds * SAMPLE_RATE), samplerate=SAMPLE_RATE,
                 channels=1, dtype="float32", device=CFG.input_device)
    sd.wait()
    return buf.flatten()


def save_wav(audio: np.ndarray, path: str):
    pcm = np.clip(audio, -1, 1)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        print("\nTRANSCRIPT:", transcribe_file(sys.argv[1]))
    else:
        audio = record_seconds(5.0)
        save_wav(audio, "test_recording.wav")
        print("[stt] saved test_recording.wav")
        print("\nTRANSCRIPT:", transcribe_array(audio))
