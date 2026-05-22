# Azure AI Solutions Architect Starter Kit

This repository is an interview-ready starter kit for deploying a repeatable Azure AI proof-of-concept environment. It is designed for business teams that want to test document search, LLM question answering, workflow automation, and KPI tracking without starting from a blank page.

The project uses Azure Developer CLI, Bicep, Docker, Azure Container Apps, FastAPI, Azure AI Search, Azure Storage, Azure Key Vault, Application Insights, and Log Analytics. It keeps the first version simple so the architecture is easy to explain in an interview and safe to extend after a discovery session.

## Problem It Solves

Business teams often ask for AI pilots before the operating model is clear. This starter kit gives an AI Solutions Architect a reusable baseline for:

- Turning a business problem into a working AI proof-of-concept.
- Showing infrastructure as code instead of one-off portal setup.
- Separating application code, cloud infrastructure, documentation, and CI/CD.
- Preparing for retrieval augmented generation (RAG) with document upload storage and Azure AI Search.
- Tracking adoption, quality, cycle time, and business value through clear KPIs.

## Architecture Overview

The API runs in Azure Container Apps and exposes placeholder endpoints for document upload, question answering, agent skill lookup, and skill grouping. Uploaded documents are intended to land in Azure Blob Storage. Azure AI Search is provisioned for future indexing and retrieval. Azure Cosmos DB for NoSQL is provisioned as a vector-capable skill registry so agents can find the right skill from a natural language request. Azure OpenAI or Azure AI Foundry connection values are passed as parameters and stored as Container App environment variables; no secrets are hardcoded.

End users are expected to consume AI through familiar business surfaces such as SharePoint, Microsoft Teams, Word, Excel, PowerPoint, Power Automate, Microsoft 365 Copilot extensions, or an agentic orchestrator such as Hermes. The API remains the governed backend that handles retrieval, model calls, telemetry, and policy controls. See [docs/end-user-consumption.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/end-user-consumption.md).

Core services:

- **Azure Container Apps** hosts the Dockerized FastAPI proof-of-concept API with consumption-based scaling.
- **Managed Identity** gives the API an Azure identity so future code can access Storage, Search, and Key Vault without embedding credentials.
- **Azure Storage Account** stores source documents for future ingestion and auditability.
- **Blob Container** separates uploaded documents from application code and makes ingestion repeatable.
- **Azure AI Search** prepares the environment for document search and RAG retrieval.
- **Azure OpenAI / Azure AI Foundry placeholders** document where model endpoint and deployment settings belong once approved.
- **Azure Key Vault** provides a controlled place for future secrets, vendor keys, or connection values.
- **Log Analytics** centralizes Container Apps platform logs.
- **Application Insights** captures API telemetry, latency, dependency health, and demo KPIs.
- **Azure Container Registry** stores the Docker image that Azure Container Apps runs.
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

Create a virtual environment and run the API:

```bash
./scripts/run-local.sh
```

Test the local endpoints:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/metrics
curl -X POST http://localhost:8000/upload -F "file=@README.md"
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"What business problem does this starter kit solve?"}'
curl -X POST http://localhost:8000/skills/search \
  -H "Content-Type: application/json" \
  -d '{"query":"create a LinkedIn post from this campaign brief","department":"marketing","task_type":"content_creation"}'
curl -X POST http://localhost:8000/skills/groups \
  -H "Content-Type: application/json" \
  -d '{"department":"marketing"}'
```

Build the Docker image locally:

```bash
./scripts/docker-local.sh
```

## Azure Deployment With azd

Initialize an azd environment:

```bash
azd init
azd env new dev
azd env set AZURE_LOCATION eastus
```

Optional model placeholders, when you have approved Azure OpenAI or Azure AI Foundry values:

```bash
azd env set AZURE_OPENAI_ENDPOINT https://your-resource.openai.azure.com/
azd env set AZURE_OPENAI_DEPLOYMENT_NAME your-chat-model-deployment
azd env set AZURE_OPENAI_API_VERSION 2024-10-21
```

Provision and deploy:

```bash
./scripts/deploy-azd.sh
```

The Bicep templates deploy a low-complexity proof-of-concept environment. Review Azure pricing before running in a paid subscription, especially for Azure AI Search, Log Analytics ingestion, and Container Apps usage.

Tear down billable Azure resources when the demo environment is no longer needed:

```bash
./scripts/teardown-azd.sh
```

## Demo Flow

1. Start with the stakeholder discovery template and define a business problem.
2. Show the architecture and explain why each Azure service exists.
3. Run the local API and call `/health` to show operational readiness.
4. Call `/metrics` to show KPI tracking structure.
5. Call `/upload` to show where documents enter the future RAG workflow.
6. Call `/ask` to show the LLM workflow contract without pretending the full RAG pipeline is complete.
7. Call `/skills/search` to show how an agent could find the right skill from a natural language request.
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
- Wire `/ask` to Azure OpenAI or Azure AI Foundry with retrieval context.
- Add authentication and role-based access for business users.
- Add automated tests and contract tests for the API.
- Add evaluation datasets for answer quality, hallucination risk, and citation coverage.
- Add budget alerts and cost dashboards.
- Convert SOP templates into the team operating model.
