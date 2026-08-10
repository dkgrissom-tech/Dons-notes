#!/usr/bin/env bash
# STEP 5 — one command to start everything
set -e
cd "$(dirname "$0")"
[ -d .venv ] || python3 -m venv .venv
source .venv/bin/activate
python -c "import faster_whisper" 2>/dev/null || pip install -q -r requirements.txt
[ -f .env ] || cp .env.example .env
exec python -m rocky.main
