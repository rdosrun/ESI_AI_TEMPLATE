# Azure AI Solutions Architect Starter Kit

This repository is an interview-ready starter kit for deploying a repeatable Azure AI proof-of-concept environment. It is designed for business teams that want to test document search, LLM question answering, workflow automation, and KPI tracking without starting from a blank page.

The project uses Azure Developer CLI, Bicep, Docker, Azure Container Registry, Azure Container Apps, FastMCP, Azure AI Search, Azure Storage, Azure Key Vault, Application Insights, and Log Analytics. It keeps the first version simple so the architecture is easy to explain in an interview and safe to extend after a discovery session.

## Problem It Solves

Business teams often ask for AI pilots before the operating model is clear. This starter kit gives an AI Solutions Architect a reusable baseline for:

- Turning a business problem into a working AI proof-of-concept.
- Showing infrastructure as code instead of one-off portal setup.
- Separating application code, cloud infrastructure, documentation, and CI/CD.
- Preparing for retrieval augmented generation (RAG) with document upload storage and Azure AI Search.
- Tracking adoption, quality, cycle time, and business value through clear KPIs.

## Architecture Overview

The FastMCP server runs in Azure Container Apps and exposes typed tools for document intake, question answering, KPI reporting, agent skill lookup, and skill grouping over Streamable HTTP at `/api/mcp`. Documents are intended to land in Azure Blob Storage. Azure AI Search is provisioned for future indexing and retrieval. Azure Cosmos DB for NoSQL is provisioned as a vector-capable skill registry so agents can find the right skill from a natural language request. Azure AI Foundry / Azure OpenAI can either be connected to an existing approved endpoint or provisioned as an optional model resource; no secrets are hardcoded.

The same Container App exposes an architecture lifecycle API under `/api/architectures`. Azure Static Web Apps provides Microsoft account sign-in and proxies authenticated `/api` requests to the linked Container App. The Flutter builder validates and versions designs in Cosmos DB, publishes immutable runtime manifests, and exposes owner-protected invocation endpoints backed by the configured Azure OpenAI deployment.

End users are expected to consume AI through familiar business surfaces such as SharePoint, Microsoft Teams, Word, Excel, PowerPoint, Power Automate, Microsoft 365 Copilot extensions, or an agentic orchestrator such as Hermes. The API remains the governed backend that handles retrieval, model calls, telemetry, and policy controls. See [docs/end-user-consumption.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/end-user-consumption.md).

Core services:

- **Azure Container Apps** hosts the Dockerized FastMCP server with consumption-based scaling.
- **Managed Identity** gives the API an Azure identity so future code can access Storage, Search, and Key Vault without embedding credentials.
- **Azure Storage Account** stores source documents for future ingestion and auditability.
- **Blob Container** separates uploaded documents from application code and makes ingestion repeatable.
- **Azure AI Search** prepares the environment for document search and RAG retrieval.
- **Azure AI Foundry / Azure OpenAI** optionally deploys a model endpoint and chat deployment, or connects the API to an existing approved endpoint.
- **Azure Key Vault** provides a controlled place for future secrets, vendor keys, or connection values.
- **Log Analytics** centralizes Container Apps platform logs.
- **Application Insights** captures API telemetry, latency, dependency health, and demo KPIs.
- **Azure Container Registry** stores the approved API image that Azure Container Apps runs.
- **Azure Static Web Apps** hosts the Flutter Agent Architecture Builder as an independently deployable web application.
- **Azure Cosmos DB for NoSQL with vector search** stores agent skills and skill groups so agents can find the right capability from natural language requests.

Consumption options:

- **SharePoint document libraries** can become approved knowledge sources for SOPs, policies, and training materials.
- **Microsoft 365 apps** can call the API through Copilot extensions, Office add-ins, Teams bots, or Power Automate flows.
- **Agentic platforms such as Hermes** can call the API as a governed tool for retrieval, question answering, and KPI-aware workflows.
- **Agent skill registry** lets agents distinguish between department and task skill groups, such as marketing social post creation versus marketing analysis.

See [docs/architecture.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/architecture.md) for the business-facing architecture notes.
See [docs/agent-skill-registry.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/agent-skill-registry.md) for the vector skill lookup design.
See [docs/hub-architecture-and-skill-governance.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/hub-architecture-and-skill-governance.md) for the hub connection model and governed skill CI/CD lifecycle.

## Prerequisites

- Azure subscription with permission to create resource groups and resources.
- Azure Developer CLI (`azd`).
- Azure CLI (`az`).
- Docker Desktop or Docker Engine.
- Python 3.11 or later for local API development.

Login once:

```bash
az login
azd auth login
```

## Local Development

### Agent Architecture Builder

The separate Flutter web application in `agent_builder/` provides a visual, local-first canvas for composing agent workflows from agents, conditions, loops, API calls, MCP tools, inputs, and outputs. Designs can be saved in browser storage or imported and exported as versioned JSON.

```bash
cd agent_builder
flutter run -d web-server --web-port 8080
```

Open `http://localhost:8080`. See [agent_builder/README.md](agent_builder/README.md) for its capabilities, validation commands, and future Azure hosting plan.

### FastMCP Server

Create a virtual environment and run the MCP server:

```bash
./scripts/run-local.sh
```

The server exposes Streamable HTTP at `http://localhost:8000/api/mcp` and an operational health probe at `/health`. Inspect and call its tools with an MCP client such as the MCP Inspector:

```bash
curl http://localhost:8000/health
npx @modelcontextprotocol/inspector http://localhost:8000/api/mcp
```

Available MCP tools:

- `get_metrics`
- `upload_document`
- `ask_question`
- `search_skills`
- `list_skill_groups`

Build the Docker image locally:

```bash
./scripts/docker-local.sh
```

Azure Container Registry stores the approved API image used by Azure Container Apps. See [docs/azure-container-registry.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/azure-container-registry.md).

## Azure Deployment With azd

### One-command tenant setup

If `azd`, Flutter, and Docker are installed, run the interactive setup wizard:

```bash
./scripts/setup-tenant.sh
```

It prompts for the Microsoft Entra tenant, subscription, environment, regions, authentication method, and AI model strategy. After showing a summary, it asks for confirmation before creating resources.

The same values can be supplied as flags for repeatable or automated setup:

```bash
./scripts/setup-tenant.sh \
  --tenant-id YOUR_TENANT_ID \
  --subscription-id YOUR_SUBSCRIPTION_ID
```

Use device-code authentication when a browser cannot be opened:

```bash
./scripts/setup-tenant.sh \
  --tenant-id YOUR_TENANT_ID \
  --subscription-id YOUR_SUBSCRIPTION_ID \
  --device-code
```

To provision the optional model as part of the same deployment, add `--deploy-ai-model` plus customer-approved model values when the defaults are unavailable. Run `./scripts/setup-tenant.sh --help` for all options. The script stores only non-secret settings under the ignored `.azure/` directory.

TODO: Confirm the approved tenant, subscription, regions, model deployment, quota, and role assignments before using this against a customer environment.

### Manual setup

Initialize an azd environment:

```bash
azd init
azd env new dev
azd env set AZURE_LOCATION eastus
```

The Agent Builder defaults to `eastus2` because Azure Static Web Apps supports a smaller regional set. Set `AGENT_BUILDER_LOCATION` if your organization requires another supported region.

Option A: connect to an existing approved Azure AI Foundry / Azure OpenAI endpoint:

```bash
azd env set AZURE_OPENAI_ENDPOINT https://your-resource.openai.azure.com/
azd env set AZURE_OPENAI_DEPLOYMENT_NAME your-chat-model-deployment
azd env set AZURE_OPENAI_API_VERSION 2024-10-21
```

Option B: let this starter provision a small Azure AI Foundry / Azure OpenAI model deployment:

```bash
azd env set DEPLOY_AI_MODEL true
azd env set AZURE_OPENAI_DEPLOYMENT_NAME gpt-4o-mini
azd env set AZURE_OPENAI_MODEL_NAME gpt-4o-mini
azd env set AZURE_OPENAI_MODEL_VERSION 2024-07-18
```

TODO: Confirm the approved region, model name, and model version for your Azure subscription before enabling model deployment. Model availability and quota vary by region and tenant.

Provision and deploy:

```bash
./scripts/deploy-azd.sh
```

This provisions both services and publishes the current Flutter builder. The deployment output includes `agentBuilderUrl`. After the first deployment, publish only builder changes with:

```bash
azd deploy agent-builder
```

Selecting **Deploy** publishes an immutable runtime manifest and returns `/api/deployments/{deploymentId}/invoke`. Send `{"input":"..."}` to that authenticated endpoint to run the compiled agent with the configured Azure OpenAI deployment. Runtime version 1.2 executes reachable API blocks and API prerequisites referenced by an agent or connected into it, passes their bounded responses to the agent as untrusted data, and returns both the raw API-step results and the model answer. MCP blocks remain descriptive until a governed MCP executor is added.

Set the exact public HTTPS hosts API blocks may call before deployment:

```bash
azd env set AGENT_API_ALLOWED_HOSTS "api.example.com,*.trusted.example.org"
azd provision
azd deploy api
```

Redirects, embedded URL credentials, private/non-public addresses, and hosts outside this list are rejected. An API block credential reference may use a Key Vault secret name or `env:VARIABLE_NAME`; the optional credential header and scheme control how the resolved value is sent.

The Agent Builder's **Search agents** workspace calls `GET /api/deployments`, searches the signed-in owner's active deployments, and invokes the selected agent from the browser while keeping Azure credentials on the managed backend. The result view shows each API call's HTTP status and response body before the grounded agent answer.

The Bicep templates deploy a low-complexity proof-of-concept environment. Review Azure pricing before running in a paid subscription, especially for Azure AI Search, Log Analytics ingestion, and Container Apps usage.

Tear down billable Azure resources when the demo environment is no longer needed:

```bash
./scripts/teardown-azd.sh
```

## Demo Flow

1. Start with the stakeholder discovery template and define a business problem.
2. Show the architecture and explain why each Azure service exists.
3. Run the local MCP server and call `/health` to show operational readiness.
4. Connect an MCP Inspector or agent to `/mcp` and list the available tools.
5. Call `get_metrics` to show KPI tracking structure.
6. Call `upload_document` and `ask_question` to show the future RAG workflow contract.
7. Call `search_skills` to show how an agent can discover the right governed capability.
8. Explain the next steps for indexing, evaluation, security review, and production readiness.

See [docs/demo-script.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/demo-script.md).

## KPI Examples

- Average response time for business questions.
- Percentage of answers grounded in approved source documents.
- User adoption by team or workflow.
- Manual hours saved per month.
- Escalation rate to human subject matter experts.
- Document ingestion success rate.
- Cost per successful answer.

See [docs/kpi-scorecard.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/kpi-scorecard.md).

## CI/CD Awareness

The GitHub Actions workflow in `.github/workflows/deploy.yml` validates the Bicep templates and includes a guarded azd deployment job. It is intentionally manual-first so an interview demo can discuss release controls before enabling automatic production deployment.

Required GitHub configuration before using deployment:

- Add an Azure federated identity credential for GitHub Actions.
- Set `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` as repository secrets.
- Review and adjust the target environment name.

## Next Steps

For an ordered integration checklist, see [docs/integration-next-steps.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/integration-next-steps.md).

- Add document parsing and chunking.
- Add SharePoint ingestion through Microsoft Graph for approved document libraries.
- Add a Teams bot, Copilot extension, Office add-in, or Power Automate connector as the first end-user channel.
- Add a Hermes tool contract after confirming the agent interface.
- Add seed data and vector search implementation for the Cosmos DB agent skill registry.
- Add Cosmos DB skill publishing from approved Git manifests.
- Create an Azure AI Search index, skillset, and indexer for the uploaded documents.
- Wire `ask_question` to Azure AI Foundry / Azure OpenAI with retrieval context and managed identity authentication.
- Add reviewer/deployer role assignments and tenant-specific access restrictions where required.
- Add automated tests and MCP contract tests.
- Add evaluation datasets for answer quality, hallucination risk, and citation coverage.
- Add budget alerts and cost dashboards.
- Convert SOP templates into the team operating model.
