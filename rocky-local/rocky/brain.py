"""
STEP 4a — The Claude Code bridge.

Runs Claude Code in headless mode and keeps one conversation alive across
turns by capturing session_id from the first reply and passing --resume
afterwards. Verified flags: -p / --print, --output-format json,
--allowedTools, --resume  (Claude Code headless docs).

Self-test:
    python -m rocky.brain "what files are in this directory"
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys

from .config import CFG

VOICE_PREAMBLE = (
    "Answer for text-to-speech playback: plain spoken sentences, no markdown, "
    "no bullet lists, no code blocks unless I explicitly ask for code. "
    "Keep it under 80 words unless detail is required.\n\n"
)


class Brain:
    def __init__(self):
        self.session_id: str | None = None
        if not shutil.which(CFG.claude_bin):
            raise RuntimeError(
                f"'{CFG.claude_bin}' not found on PATH. "
                "Install with: npm i -g @anthropic-ai/claude-code"
            )

    def _cmd(self, prompt: str) -> list[str]:
        cmd = [CFG.claude_bin, "-p", (prompt.replace("\n", " ") if sys.platform.startswith("win") else prompt),
               "--output-format", "json",
               "--allowedTools", CFG.claude_tools]
        if CFG.persist_session and self.session_id:
            cmd += ["--resume", self.session_id]
        return cmd

    def ask(self, text: str) -> str:
        prompt = text if self.session_id else VOICE_PREAMBLE + text
        try:
            p = subprocess.run(
                self._cmd(prompt),
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                cwd=CFG.claude_cwd, timeout=CFG.claude_timeout,
                shell=sys.platform.startswith("win"),
            )
        except subprocess.TimeoutExpired:
            return "That took too long, so I stopped it."

        if p.returncode != 0:
            err = (p.stderr or "").strip().splitlines()
            detail = err[-1] if err else f"exit {p.returncode}"
            print(f"[brain] claude failed: {detail}")
            # A stale session id is the usual cause — drop it and retry once.
            if self.session_id:
                self.session_id = None
                return self.ask(text)
            return "Claude Code returned an error. Check the terminal."

        try:
            data = json.loads(p.stdout)
        except json.JSONDecodeError:
            return (p.stdout or "").strip() or "Empty response."

        if isinstance(data, list):                # stream-json safety net
            data = data[-1]
        self.session_id = data.get("session_id") or self.session_id
        if data.get("is_error"):
            return "Claude reported an error running that."
        return (data.get("result") or "").strip() or "No answer came back."

    def reset(self):
        self.session_id = None


if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) or "Say hello in one short sentence."
    b = Brain()
    print("\n" + b.ask(q))
    print(f"\n[brain] session_id={b.session_id}")
