"""
STEP 4b / STEP 5 — Push-to-talk loop, end to end.

Hold the hotkey (default: right Ctrl) -> speak -> release.
    mic -> faster-whisper (local) -> Claude Code -> Piper (local) -> speakers

There is no browser anywhere in this pipeline, which is precisely why the
permission problems that plague Web Speech API do not exist here. sounddevice
opens the OS audio device through PortAudio directly.

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
 |_| \_\\___/ \____|_|\_\  |_|       hotkey: hold {key}
"""


class PushToTalk:
    def __init__(self):
        self.frames: list[np.ndarray] = []
        self.recording = False
        self.started_at = 0.0
        self.busy = False           # true while thinking/speaking
        self.jobs: queue.Queue[np.ndarray] = queue.Queue()
        self.brain = Brain()
        self.stream: sd.InputStream | None = None

    # ---------------------------------------------------------- audio in
    def _callback(self, indata, frames, time_info, status):
        if status:
            print(f"[audio] {status}")
        if self.recording:
            self.frames.append(indata[:, 0].copy())
            if time.time() - self.started_at > CFG.max_record_s:
                print("[ptt] max length reached")
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

    # ------------------------------------------------------------- ptt
    def start(self):
        if self.recording or self.busy:
            return
        self.frames = []
        self.recording = True
        self.started_at = time.time()
        print("\n[ptt] ● recording — release to send")

    def stop(self):
        if not self.recording:
            return
        self.recording = False
        held_ms = (time.time() - self.started_at) * 1000
        audio = np.concatenate(self.frames) if self.frames else np.zeros(0, "float32")
        self.frames = []
        if held_ms < CFG.min_hold_ms:
            print(f"[ptt] ignored tap ({held_ms:.0f}ms)")
            return
        print(f"[ptt] ○ captured {len(audio)/SAMPLE_RATE:.1f}s")
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
        from pynput import keyboard

        key_name = CFG.hotkey
        target = getattr(keyboard.Key, key_name, None)
        if target is None and len(key_name) == 1:
            target = keyboard.KeyCode.from_char(key_name)
        if target is None:
            sys.exit(f"Unknown HOTKEY '{key_name}'. Try ctrl_r, alt_r, f9, or a single char.")

        print(BANNER.format(stt=CFG.stt_model, dev=CFG.stt_device,
                            tts=CFG.tts_backend, key=key_name))

        get_model()          # preload so the first turn isn't slow
        self.open_stream()
        threading.Thread(target=self.worker, daemon=True).start()

        print(f"\n  Hold [{key_name}] and speak. Say 'reset' for a new session, "
              f"'quit' to exit. Ctrl+C to kill.\n")

        def on_press(k):
            if k == target:
                self.start()

        def on_release(k):
            if k == target:
                self.stop()

        with keyboard.Listener(on_press=on_press, on_release=on_release) as l:
            try:
                l.join()
            except KeyboardInterrupt:
                pass


def main():
    try:
        PushToTalk().run()
    except KeyboardInterrupt:
        print("\nbye")
    except RuntimeError as e:
        sys.exit(str(e))


if __name__ == "__main__":
    main()
