# Rocky — local voice layer for Claude Code

Hold a key, talk, release. Your speech is transcribed **on your machine**, sent
to Claude Code as a prompt, and the answer is spoken back **from your machine**.

```
mic ──► faster-whisper (local) ──► claude -p ──► Piper (local) ──► speakers
        audio never leaves                        text never leaves
```

## Why this fixes the mic problem for good

Every microphone failure in the browser version — `SecurityError: Invalid
security origin`, iframe permission policy, stuck `denied` states, Edge's
speech backend — came from one root cause: **the mic was behind a browser
permission model.**

This has no browser. `sounddevice` opens the OS audio device directly through
PortAudio. There is no origin, no permission prompt, no HTTPS requirement, no
iframe. The OS grants mic access to the Python process once (macOS asks the
first time; Windows and Linux just allow it) and that is the end of it.

## A note on ElevenLabs

You asked for ElevenLabs, and you also asked that audio never leave the
machine. Those are in tension, so TTS is a swappable backend:

| `TTS_BACKEND` | What leaves your machine | Voice quality |
|---|---|---|
| `piper` (default) | nothing | good, robotic-adjacent |
| `elevenlabs` | the reply **text** only | excellent |

Your **microphone audio is local in both modes** — STT never touches a network.
Flip the backend in `.env` whenever you want.

---

# The five steps

Nothing installs itself. Each step is a command you run deliberately.

## STEP 1 — Check the machine

```bash
python preflight.py
```

Installs nothing. Reports OS, Python, RAM, disk, GPU/VRAM, which of
ffmpeg / node / claude / piper you already have, and every microphone it can
see. Ends with a **verdict** naming the exact STT model your hardware should
run and the three `.env` lines to paste.

If it lists blockers, fix those first. The likely one is Claude Code itself:

```bash
npm i -g @anthropic-ai/claude-code
```

> ### ⛔ STOP — read the verdict before continuing.

## STEP 2 — Install and test speech to text

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

cp .env.example .env               # Windows: Copy-Item .env.example .env
# paste STT_MODEL / STT_DEVICE / STT_COMPUTE from step 1 into .env
```

Test it. This records 5 seconds and transcribes it:

```bash
python -m rocky.stt
```

The model downloads once from Hugging Face (40 MB for `base.en`, 1.5 GB for
`large-v3`), then runs offline forever. You should see your words printed and
`test_recording.wav` written. If the transcript is wrong but the WAV sounds
fine, you picked too small a model. If the WAV is silent, set `INPUT_DEVICE` in
`.env` to a device index from step 1.

> ### ⛔ STOP — confirm the transcript is accurate.

## STEP 3 — Install and test the voice

```bash
python -m rocky.tts
```

Downloads the Piper voice (~60 MB, once) and speaks a test line. If you hear
it, step 3 passes. Other voices: `python -m piper.download_voices` lists all
100+, then set `PIPER_VOICE` in `.env`.

For ElevenLabs instead, put in `.env`:

```
TTS_BACKEND=elevenlabs
ELEVENLABS_API_KEY=sk_...
```

and re-run the same test. It falls back to Piper automatically if the key is
missing or the API errors, so the loop never dies from a cloud failure.

> ### ⛔ STOP — confirm you heard audio.

## STEP 4 — Wire the loop

First check the Claude Code bridge alone, no audio involved:

```bash
python -m rocky.brain "what files are in this directory"
```

That runs `claude -p --output-format json` and prints the parsed answer plus
the `session_id` it captured. Session id is how follow-up questions keep
context — turn two passes `--resume <id>`, so "now do that to the other file"
works.

Set `CLAUDE_CWD` in `.env` to the project you want Claude operating in, and
trim `CLAUDE_ALLOWED_TOOLS` if you don't want it writing files by voice.

Then the whole thing:

```bash
python -m rocky.main
```

Just speak — the mic notices when you start and stop talking, no key to hold.
Tune sensitivity with `VAD_THRESHOLD=` (higher = less sensitive to background
noise) and `VAD_SILENCE_MS=` (how long a pause ends your turn) in `.env`.

> ### ⛔ STOP — confirm one full round trip.

## STEP 5 — One command

```bash
./start.sh          # macOS / Linux
.\start.ps1         # Windows
```

Creates the venv if missing, installs deps if missing, copies `.env` if
missing, launches the loop. That's the daily driver.

---

# Voice commands

| Say | Effect |
|---|---|
| "reset" / "new session" | drops the Claude session, starts fresh |
| "quit" / "shut down" | exits |

# Design decisions worth knowing

- **Voice-activated, not push-to-talk.** No global hotkey — laptop OEM
  keyboard drivers frequently swallow Ctrl/Fn-row keys before a Python-level
  hook ever sees them, which makes hotkeys unreliable across machines. The
  mic stream's own RMS energy starts and ends each turn instead.
- **Silence gate.** Clips under an RMS threshold are dropped, so background
  noise never invokes the agent. Turns under `MIN_HOLD_MS` are ignored too.
- **`condition_on_previous_text=False`** in Whisper. Prevents the classic
  hallucination spiral where the model loops a phrase forever on quiet audio.
- **Single worker thread.** Recording is locked out while thinking or speaking,
  so Rocky can't hear itself or stack overlapping requests.
- **Stale session recovery.** If `--resume` fails because the session expired,
  the bridge drops the id and retries once instead of dying.
- **Markdown stripped before TTS**, so the voice doesn't read asterisks and
  backticks out loud.

# Known platform quirks

- **macOS:** the first run triggers a Microphone permission prompt. Grant it
  to the Terminal app you're running from.
- **Windows:** if `pip install sounddevice` can't find PortAudio, install the
  wheel from PyPI rather than building. `py -3.12` is the safest interpreter.
- **GPU:** `ctranslate2` needs CUDA 12 + cuDNN 9. On CUDA 11 pin
  `ctranslate2==3.24.0`. Run `nvidia-smi` and match the header version.

# Handing this to Claude Code

Everything is stubbed and runnable; the sharp edges left are wake-word mode,
barge-in (interrupting playback mid-sentence), and streaming partial
transcripts. Point Claude Code at this directory and it has the full contract:
`config.py` is the single source of truth, each module has a `__main__`
self-test, and each step gates the next.
