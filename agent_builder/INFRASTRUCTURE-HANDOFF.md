# Agent Builder Infrastructure Handoff

## Purpose

The Agent Architecture Builder is a standalone Flutter web application under `agent_builder/`. It gives users a visual canvas for designing agent workflows from blocks such as agents, conditions, loops, API calls, and MCP tools.

The builder is separate from the FastMCP service under `src/api/`. Keeping the frontend and backend independently deployable makes the demo easier to explain and allows each component to scale or change without forcing a combined release.

## Current User Experience

Users can:

- Drag blocks onto a visual canvas.
- Move blocks and connect them with labeled links.
- Build if/else-if/else routing rules.
- Configure agent instructions.
- Configure API and MCP connection metadata.
- Allow an agent to reference selected API and MCP blocks.
- Collapse the side panels.
- View the architecture as JSON.
- Save a draft in browser local storage.
- import and export architecture JSON files.

The right-side chat is currently a local planning placeholder. It does not call a model or backend service yet.

## Important Files

| File | Responsibility |
| --- | --- |
| `agent_builder/lib/main.dart` | Canvas UI, block models, connection routing, inspectors, and JSON serialization. |
| `agent_builder/lib/storage_web.dart` | Browser local storage plus JSON file import/export. |
| `agent_builder/lib/storage_stub.dart` | Non-web storage implementation used by tests. |
| `agent_builder/test/widget_test.dart` | Model and interaction regression tests. |
| `agent_builder/pubspec.yaml` | Flutter dependencies and SDK constraints. |
| `agent_builder/web/` | Flutter web bootstrap files and icons. |
| `agent_builder/web/staticwebapp.config.json` | Static Web Apps routing and baseline browser security headers. |
| `agent_builder/build/web/` | Generated static deployment output; do not edit or commit it. |
| `src/api/main.py` | Separate FastMCP backend and future governed tool layer. |
| `infra/main.bicep` | Current Azure infrastructure composition root. |
| `azure.yaml` | Current Azure Developer CLI project and service definition. |
| `schemas/agent-architecture.schema.json` | Portable version `1.0` JSON contract. |
| `docs/agent-architecture-schema.md` | Schema validation boundary and migration policy. |

## Local Build And Validation

Flutter is currently installed at:

```text
/home/richardh/develop/flutter
```

Add it to the current shell path:

```bash
export PATH="/home/richardh/develop/flutter/bin:$PATH"
```

Run locally:

```bash
cd agent_builder
flutter pub get
flutter run -d web-server --web-port 8080
```

Open `http://localhost:8080`.

Validate before changing infrastructure:

```bash
cd agent_builder
flutter analyze
flutter test
flutter build web
```

The production-ready static files are generated under `agent_builder/build/web/`.

## Architecture JSON Contract

Architectures currently use schema version `1.0` and contain:

```json
{
  "schemaVersion": "1.0",
  "name": "Example workflow",
  "updatedAt": "2026-08-16T00:00:00.000Z",
  "nodes": [],
  "edges": []
}
```

Each node stores a stable ID, type, canvas position, title, description, and type-specific `config` object. Each edge stores its source node, destination node, and optional label.

Agent blocks can store:

```json
{
  "instructions": "Use approved sources and cite the result.",
  "integrationRefs": ["api-node-id", "mcp-node-id"]
}
```

API and MCP blocks can store endpoint and protocol metadata. Credential fields must contain only a reference such as a Key Vault secret name or environment-variable name. Do not store raw tokens in the architecture JSON, browser storage, Git, or Flutter build output.

## Current Storage Model

The application is local-first:

- The current draft is stored in browser local storage.
- Export downloads a JSON file.
- Import reads a user-selected JSON file.
- There is no server-side architecture database yet.
- Microsoft accounts can sign in through Azure Static Web Apps built-in Entra authentication.
- The linked Container Apps backend receives the platform-provided client principal for architecture ownership.

Browser storage is appropriate for the current localhost demo but not for multi-user or production use.

## Recommended Azure Hosting

Use Azure Static Web Apps as the initial hosting target for the Flutter frontend.

Business reasons:

- Flutter produces static web assets.
- Static Web Apps provides managed HTTPS and simple deployment.
- The frontend can be released independently from the FastMCP Container App.
- Microsoft Entra ID integration and API routing can be added when the pilot needs authenticated users.
- The hosting cost and operational burden remain low for an interview demonstration or early pilot.

An Azure Storage static website plus Azure Front Door is another option, but it introduces more infrastructure than this starter currently needs.

## Implemented Infrastructure

The starter now:

1. Provisions Azure Static Web Apps through `infra/modules/static-web-app.bicep`.
2. Outputs the deployed frontend URL and hostname from `infra/main.bicep`.
3. Registers `agent-builder` as an independent `azd` service.
4. Builds Flutter during `azd package` / `azd up` and publishes only `build/web`.
5. Validates Flutter in GitHub Actions before the guarded deployment job.
6. Adds SPA fallback routing and baseline browser security headers.
7. Provides a formal architecture JSON Schema and migration policy.
8. Keeps the FastMCP Container App independently deployable.

TODO: Confirm whether the target organization prefers Azure Static Web Apps managed deployment tokens or GitHub OIDC with Azure RBAC. Prefer OIDC where supported so a long-lived deployment secret is not required.

## Future Server-Side Persistence

For authenticated multi-user saving, add a backend contract instead of writing directly from Flutter to Cosmos DB or Storage.

Recommended flow:

1. User signs in with Microsoft Entra ID.
2. Flutter calls an authenticated architecture API.
3. The API validates the JSON schema and user authorization.
4. The API stores the architecture and ownership metadata.
5. The API returns architecture IDs and versions to the user.

The existing FastMCP service is intended for agent tool access, not necessarily conventional browser CRUD. A future agent should make an explicit decision between:

- Adding authenticated HTTP architecture endpoints alongside FastMCP.
- Creating a separate small persistence API.
- Using an Azure Static Web Apps managed API if it satisfies the governance requirements.

Do not expose Cosmos DB keys, Storage keys, model credentials, or MCP bearer tokens to the Flutter client.

## Security Requirements

- Add reviewer/deployer role assignments before enabling live agent creation.
- Authorize users per architecture owner, team, or approved role.
- Validate uploaded JSON size, schema version, node types, and references on the server.
- Treat API and MCP endpoint metadata as potentially sensitive configuration.
- Resolve credential references only in a trusted backend using managed identity and Key Vault.
- Never bundle secrets into Flutter compile-time values because web assets are public to the browser.
- Add Content Security Policy and allowed-origin rules for the deployed hostname.
- Configure FastMCP authentication before allowing the public frontend or external agents to call it.
- Add audit telemetry for saves, imports, exports, and architecture execution.

## CI/CD Expectations

Before deployment, CI should run:

```bash
cd agent_builder
flutter pub get
flutter analyze
flutter test
flutter build web
```

The deployment job should publish only `agent_builder/build/web/`. It should not publish `.dart_tool/`, local browser state, `.env` files, `.azure/`, or `.codex/`.

Use separate validation and deployment jobs. Keep production deployment behind an approved GitHub environment or manual release gate until authentication, persistence, and security review are complete.

## Observability And Business Metrics

When the frontend is hosted, consider tracking:

- Successful and failed application loads.
- Architecture creation and save counts.
- Import validation failures.
- Number and types of blocks used.
- Time from new architecture to first valid save.
- Backend/API failures without logging secrets or full user instructions.

Application Insights can be used, but telemetry collection and user notice requirements should be confirmed before enabling browser analytics.

## Known TODOs

The implementation sequence and frontend/backend hookup contracts are maintained in [TODO.md](TODO.md).

- Decide how approved architecture JSON becomes an executable workflow deployment.
- Add reviewer/deployer authorization and tenant-specific restrictions if required.
- Add server-side architecture persistence and version history.
- Add client and server validation against the formal JSON Schema; the schema and migration policy now exist.
- Connect the planning chat to an approved Azure AI Foundry model or governed agent.
- Decide how a saved visual architecture becomes an executable workflow.
- Add authorization rules for which users and agents may reference each API or MCP integration.
- Add Key Vault-backed credential resolution in a trusted backend.
- Add custom-domain, CSP, CORS, and private-network requirements after stakeholder discovery.

## Guardrails For Future Agents

- Inspect the existing Bicep, `azure.yaml`, workflows, and current Git diff before making infrastructure changes.
- Preserve the separation between the static Flutter frontend and FastMCP backend unless a documented requirement changes it.
- Keep Bicep modules small and explain Azure choices in business terms.
- Do not hardcode subscription IDs, tenant IDs, endpoints, tokens, deployment credentials, or model details.
- Use TODO comments for customer-specific Azure values.
- Do not commit `.azure/`, `.env`, `.codex/`, `agent_builder/build/`, or `.dart_tool/`.
- Run Flutter validation and Bicep validation before handing off infrastructure work.
