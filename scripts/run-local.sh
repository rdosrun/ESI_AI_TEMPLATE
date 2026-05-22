#!/usr/bin/env bash
set -euo pipefail

python -m venv .venv
source .venv/bin/activate
pip install -r src/api/requirements.txt
uvicorn main:app --app-dir src/api --reload --port 8000
