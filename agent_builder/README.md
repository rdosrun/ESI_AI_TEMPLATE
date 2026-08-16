# Agent Architecture Builder

A local-first Flutter web canvas for designing agent workflows. It is intentionally isolated from the backend starter so it can later be hosted independently on Azure Static Web Apps or another approved web host.

For infrastructure ownership, Azure hosting guidance, security boundaries, and future deployment work, see [INFRASTRUCTURE-HANDOFF.md](INFRASTRUCTURE-HANDOFF.md).

## Current capabilities

- Drag blocks from the left palette onto the canvas.
- Move and edit workflow blocks.
- Collapse either side panel to maximize canvas space.
- Link blocks by dragging the circular output port to another block, or by selecting **Link** and clicking the source and destination.
- Preview a live connection line while dragging, then attach it to the destination block's pentagonal input port.
- Fan multiple outgoing connections into separate routed lanes so every destination remains visible.
- Click a connection to label or remove it.
- Model agents, conditions, loops, API calls, MCP tools, inputs, and outputs.
- Build ordered if/else-if/else rules with outgoing connection labels.
- Configure API URLs and HTTP methods on API blocks.
- Configure MCP server URLs, transports, and tool names on MCP blocks.
- Reference credentials by Key Vault secret name or environment variable without storing raw tokens in exported JSON.
- Write detailed instructions for agent blocks.
- Select API and MCP blocks as governed inputs an agent is allowed to reference.
- View the architecture as versioned JSON.
- Save the current draft in browser storage.
- Save validated architecture versions to Cosmos DB through the backend API.
- Submit a deployment request and display its lifecycle status.
- Export JSON to a file and upload it later to continue editing.
- Use the right-side planning chat placeholder while designing.

The chat currently returns local guidance only. A future iteration can connect it to the repository's FastMCP server or an approved Azure AI Foundry agent.

## Run locally

```bash
cd agent_builder
flutter pub get
flutter run -d web-server --web-port 8080
```

Open `http://localhost:8080` in a browser.

## Validate

```bash
cd agent_builder
flutter analyze
flutter test
flutter build web
```

## Deploy to Azure

The root `azd` project provisions an Azure Static Web App and publishes the compiled Flutter site. From the repository root:

```bash
./scripts/setup-tenant.sh
```

The wizard prompts for the tenant, subscription, regions, authentication method, and optional model configuration. For repeatable setup, pass the values as flags:

```bash
./scripts/setup-tenant.sh \
  --tenant-id YOUR_TENANT_ID \
  --subscription-id YOUR_SUBSCRIPTION_ID
```

The complete option list is available through `./scripts/setup-tenant.sh --help`. For manual setup:

```bash
azd env new dev
azd env set AZURE_LOCATION eastus
azd up
```

Azure Static Web Apps defaults to `eastus2`. Override it before `azd up` when required:

```bash
azd env set AGENT_BUILDER_LOCATION westus2
```

Run `azd env get-values` after deployment and open the `agentBuilderUrl` shown in the deployment outputs. A later UI-only release can be sent with:

```bash
azd deploy agent-builder
```

The builder now has separate **Local**, **Cloud save**, and **Deploy** actions. Deploy validates the exact cloud version, publishes an immutable runtime manifest, and reports `active` with its protected invocation endpoint. Runtime version 1.2 executes reachable API blocks plus API prerequisites referenced by or connected into an agent, supplies their bounded responses to the configured Azure OpenAI model, and returns API and model results separately.

Select **Search agents** in the top bar to switch to the deployed-agent workspace. It lists only active agents owned by the signed-in Microsoft account, supports name search, and provides a prompt runner that displays the model response and token usage.

Use the moon/sun button in the top bar to switch between light and dark mode. The preference is stored in the browser and restored on the next visit.

API hosts must be included in `AGENT_API_ALLOWED_HOSTS`. For POST, PUT, PATCH, or DELETE blocks, use the JSON body template field and insert `{{input}}` where the runner prompt belongs. Credential references resolve from Key Vault by default or from an environment variable when written as `env:VARIABLE_NAME`.

## Microsoft sign-in

Azure Static Web Apps provides the Microsoft Entra sign-in flow at `/.auth/login/aad`. The Flutter app reads the signed-in principal from `/.auth/me`, while the linked Container Apps backend receives a platform-signed identity header. Cosmos ownership comes from that verified user ID rather than browser JSON.

The preconfigured provider supports organizational and personal Microsoft accounts. GitHub sign-in is blocked in `staticwebapp.config.json`. Cloud save and deploy require the built-in `authenticated` role; local browser save remains available without sign-in.

The linked Container Apps backend requires the Azure Static Web Apps Standard plan. Add reviewer/deployer role authorization before enabling live runtime creation.

The exported document contract is defined by [`../schemas/agent-architecture.schema.json`](../schemas/agent-architecture.schema.json), with compatibility and migration rules in [`../docs/agent-architecture-schema.md`](../docs/agent-architecture-schema.md).

## Implementation TODOs

See [TODO.md](TODO.md) for the ordered Flutter and Azure implementation roadmap. It describes the user-facing work, backend contracts, Azure hookups, security boundaries, acceptance criteria, and the path from a saved design to a governed agent deployment.

Recommended order:

1. Formal schema and validation.
2. Reviewer and deployer authorization.
3. Cloud persistence and version history.
4. Planning chat and connection testing.
5. Review and governed agent deployment.
6. Audit telemetry and production hardening.
