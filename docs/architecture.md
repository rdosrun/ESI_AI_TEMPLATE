# Architecture

## Purpose

This architecture gives business teams a repeatable AI proof-of-concept environment. It supports the early questions that usually matter most: Can we upload approved documents, search them, ask questions, route agents to the right skills, measure usage, and operate the system responsibly?

## High-Level Flow

1. A user or workflow sends a document to the FastAPI `/upload` endpoint.
2. The API will store the document in Azure Blob Storage.
3. A future ingestion process will extract text, chunk it, and index it in Azure AI Search.
4. A user sends a question to `/ask`.
5. The API will retrieve relevant document chunks from Azure AI Search.
6. The API will send the question and retrieved context to an approved Azure AI Foundry / Azure OpenAI model deployment.
7. The API returns an answer with citations and logs telemetry for KPI reporting.
8. For agentic workflows, an agent can call `/skills/search` or `/skills/groups` to find approved skills by department, task, and natural language similarity.

## End-User Consumption

Users should not need to know that Azure OpenAI, Azure AI Search, or Container Apps are behind the solution. They should consume AI from the business tools they already use:

- SharePoint document libraries for approved source content.
- Microsoft Teams for chat-based assistance.
- Word, Excel, and PowerPoint through Office add-ins or Microsoft 365 Copilot extensions.
- Power Automate for workflow-triggered AI actions.
- Agentic platforms such as Hermes for multi-step planning, retrieval, drafting, and escalation.

The FastAPI service acts as the governed backend. It keeps model access, retrieval logic, telemetry, and future policy checks in one place.

## Service Responsibilities

| Service | Business Reason |
| --- | --- |
| Azure Container Apps | Hosts the API without a server management burden. This keeps the pilot fast to deploy and easy to scale down. |
| Azure Container Registry | Stores the approved API image so deployments use a known, repeatable build artifact. |
| Managed Identity | Lets the API access Azure services without storing passwords in code or configuration files. |
| Azure Storage Account | Stores uploaded business documents as the source of truth for future indexing. |
| Blob Container | Keeps proof-of-concept documents isolated from other files and makes retention rules easier to apply. |
| Azure AI Search | Provides document retrieval for RAG workflows so answers can be grounded in approved content. |
| Azure Cosmos DB for NoSQL with vector search | Stores agent skills, metadata, and skill groups so agents can find the right capability using natural language. |
| Azure AI Foundry / Azure OpenAI | Provides the governed model endpoint. The starter can connect to an existing approved endpoint or optionally deploy a small chat model deployment for demos. |
| Azure Key Vault | Provides a governed place for future secrets or vendor credentials when managed identity is not enough. |
| Log Analytics | Centralizes logs so support teams can investigate issues. |
| Application Insights | Tracks API health, latency, errors, and usage for stakeholder reporting. |

See [end-user-consumption.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/end-user-consumption.md) for the SharePoint, Office, and agentic consumption patterns.
See [agent-skill-registry.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/agent-skill-registry.md) for skill lookup and grouping.
See [azure-container-registry.md](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/docs/azure-container-registry.md) for the image registry and traceability notes.

## Security Posture

- No secrets are committed to the repository.
- The API uses managed identity for future Azure service access.
- Blob public access is disabled.
- Container registry admin user is disabled.
- The API image is stored in Azure Container Registry with metadata labels for traceability.
- Key Vault uses RBAC authorization.
- Model values are parameters, and managed identity is assigned the Cognitive Services OpenAI User role when the starter provisions the model resource.

## Cost Posture

This starter uses low-complexity settings suitable for a proof of concept:

- Container Apps can scale to zero.
- Azure AI Search uses the free SKU by default.
- Storage uses Standard LRS.
- Container Registry uses Basic because a registry is needed for the container image.
- Cosmos DB uses serverless mode for the starter skill registry.
- Log Analytics retention is set to 30 days.

Review Azure pricing before deploying to a paid subscription.

## Production Gaps

- Authentication and authorization are not implemented yet.
- Document parsing, chunking, and indexing are placeholders.
- The `/ask` endpoint checks model configuration but does not call a model yet.
- The `/skills/search` endpoint does not query Cosmos DB vector search yet.
- Private networking is not configured.
- Automated evaluation and red-team test cases are not included yet.
- Budget alerts and operational runbooks should be added before production.
