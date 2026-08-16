#!/usr/bin/env bash
set -euo pipefail

python -m venv .venv
source .venv/bin/activate
pip install -r src/api/requirements.txt
fastmcp run src/api/main.py:mcp --transport http --host 0.0.0.0 --port 8000 --reload
