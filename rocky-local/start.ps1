# STEP 5 — one command to start everything (Windows)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path .venv)) { py -3.12 -m venv .venv }
& .\.venv\Scripts\Activate.ps1
python -c "import faster_whisper" 2>$null
if ($LASTEXITCODE -ne 0) { pip install -q -r requirements.txt }
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
python -m rocky.main
