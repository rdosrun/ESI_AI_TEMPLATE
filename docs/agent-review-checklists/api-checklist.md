# MCP Server Review Checklist

Use this checklist to review the FastMCP starter service.

- [x] `src/api/main.py` exists.
- [x] `GET /health` returns service health.
- [x] `/mcp` exposes Streamable HTTP MCP transport.
- [x] `get_metrics` returns starter KPI placeholders.
- [x] `upload_document` returns the future storage intent.
- [x] `ask_question` accepts a question and returns a clear placeholder response.
- [x] `search_skills` returns placeholder natural language skill lookup results.
- [x] `list_skill_groups` returns placeholder department/task skill groups.
- [x] API code does not contain secrets.
- [x] API reads deployment configuration from environment variables.
- [x] `requirements.txt` contains minimal runtime dependencies.
- [x] `Dockerfile` builds a small Python FastMCP container.

## Follow-Up Checks

- [ ] Run `./scripts/run-local.sh`.
- [ ] Run `./scripts/docker-local.sh`.
- [ ] Test `/health`, MCP tool discovery, and all five tool calls.
- [ ] Add unit tests before expanding the API behavior.
