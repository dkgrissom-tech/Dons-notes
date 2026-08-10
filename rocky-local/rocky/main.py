"""
STEP 4b / STEP 5 — Voice-activated loop, end to end.

Just speak -> the mic itself notices and starts capturing -> stop talking
-> it sends what you said.
    mic -> faster-whisper (local) -> Claude Code -> Piper (local) -> speakers

There is no browser anywhere in this pipeline, which is precisely why the
permission problems that plague Web Speech API do not exist here. sounddevice
opens the OS audio device through PortAudio directly. No global hotkey is
used — laptop OEM keyboard drivers frequently swallow Ctrl/Fn-row keys
before they ever reach a Python-level hook, which makes any hotkey-based
push-to-talk unreliable across machines. Voice-activity detection on the
raw audio stream sidesteps that entirely.

Start:
    python -m rocky.main
"""
from __future__ import annotations

import queue
import sys
import threading
import time

import numpy as np
import sounddevice as sd

from .config import CFG
from .stt import SAMPLE_RATE, transcribe_array, get_model, save_wav
from .tts import speak
from .brain import Brain

BANNER = r"""
  ____   ___   ____ _  ____   __
 |  _ \ / _ \ / ___| |/ /\ \ / /     local voice loop
 | |_) | | | | |   | ' /  \ V /      stt: {stt}  ({dev})
 |  _ <| |_| | |___| . \   | |       tts: {tts}
 |_| \_\\___/ \____|_|\_\  |_|       mode: voice-activated (just speak)
"""


class VoiceLoop:
    def __init__(self):
        self.frames: list[np.ndarray] = []
        self.recording = False
        self.started_at = 0.0
        self.last_voice_at = 0.0
        self.busy = False           # true while thinking/speaking
        self.jobs: queue.Queue[np.ndarray] = queue.Queue()
        self.brain = Brain()
        self.stream: sd.InputStream | None = None

    # ---------------------------------------------------------- audio in
    def _callback(self, indata, frames, time_info, status):
        if status:
            print(f"[audio] {status}")
        if self.busy:
            return  # don't listen to ourselves while thinking/speaking

        rms = float(np.sqrt(np.mean(np.square(indata[:, 0]))))
        now = time.time()
        voiced = rms > CFG.vad_threshold

        if not self.recording:
            if voiced:
                self.start()
                self.last_voice_at = now
                self.frames.append(indata[:, 0].copy())
            return

        self.frames.append(indata[:, 0].copy())
        if voiced:
            self.last_voice_at = now
        elif (now - self.last_voice_at) * 1000 > CFG.vad_silence_ms:
            self.stop()
            return
        if now - self.started_at > CFG.max_record_s:
            print("[vad] max length reached")
            self.stop()

    def open_stream(self):
        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE, channels=1, dtype="float32",
            blocksize=1024, device=CFG.input_device, callback=self._callback,
        )
        self.stream.start()
        dev = sd.query_devices(CFG.input_device, "input")["name"] \
            if CFG.input_device is not None else sd.query_devices(kind="input")["name"]
        print(f"[audio] capturing from: {dev}")

    # ------------------------------------------------------------- vad
    def start(self):
        if self.recording or self.busy:
            return
        self.frames = []
        self.recording = True
        self.started_at = time.time()
        print("\n[vad] * hearing you...")

    def stop(self):
        if not self.recording:
            return
        self.recording = False
        held_ms = (time.time() - self.started_at) * 1000
        audio = np.concatenate(self.frames) if self.frames else np.zeros(0, "float32")
        self.frames = []
        if held_ms < CFG.min_hold_ms:
            print(f"[vad] ignored blip ({held_ms:.0f}ms)")
            return
        print(f"[vad] captured {len(audio)/SAMPLE_RATE:.1f}s")
        self.jobs.put(audio)

    # ----------------------------------------------------------- worker
    def worker(self):
        while True:
            audio = self.jobs.get()
            self.busy = True
            try:
                text = transcribe_array(audio)
                if not text:
                    print("[loop] nothing intelligible")
                    continue
                print(f"\n  YOU:   {text}")

                low = text.lower().strip(" .!?")
                if low in ("reset", "new session", "start over"):
                    self.brain.reset()
                    speak("Fresh session.")
                    continue
                if low in ("quit", "exit", "shut down"):
                    speak("Shutting down.")
                    import os
                    os._exit(0)

                reply = self.brain.ask(text)
                print(f"  ROCKY: {reply}\n")
                speak(reply)
            except Exception as e:
                print(f"[loop] error: {type(e).__name__}: {e}")
                speak("Something went wrong. Check the terminal.")
            finally:
                self.busy = False
                self.jobs.task_done()

    # ------------------------------------------------------------- run
    def run(self):
        print(BANNER.format(stt=CFG.stt_model, dev=CFG.stt_device,
                            tts=CFG.tts_backend))

        get_model()          # preload so the first turn isn't slow
        self.open_stream()
        threading.Thread(target=self.worker, daemon=True).start()

        print("\n  Just speak. Say 'reset' for a new session, "
              "'quit' to exit. Ctrl+C to kill.\n")

        try:
            while True:
                time.sleep(0.5)
        except KeyboardInterrupt:
            pass


def main():
    try:
        VoiceLoop().run()
    except KeyboardInterrupt:
        print("\nbye")
    except RuntimeError as e:
        sys.exit(str(e))


if __name__ == "__main__":
    main()
