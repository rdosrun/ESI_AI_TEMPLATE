# API Review Checklist

Use this checklist to review the FastAPI starter service.

- [x] `src/api/main.py` exists.
- [x] `GET /health` returns service health.
- [x] `GET /metrics` returns starter KPI placeholders.
- [x] `POST /upload` accepts a file and returns the future storage path intent.
- [x] `POST /ask` accepts a question and returns a clear placeholder response.
- [x] `POST /skills/search` returns placeholder natural language skill lookup results.
- [x] `POST /skills/groups` returns placeholder department/task skill group results.
- [x] API code does not contain secrets.
- [x] API reads deployment configuration from environment variables.
- [x] `requirements.txt` contains minimal runtime dependencies.
- [x] `Dockerfile` builds a small Python FastAPI container.

## Follow-Up Checks

- [ ] Run `./scripts/run-local.sh`.
- [ ] Run `./scripts/docker-local.sh`.
- [ ] Test `/health`, `/metrics`, `/upload`, `/ask`, `/skills/search`, and `/skills/groups`.
- [ ] Add unit tests before expanding the API behavior.
