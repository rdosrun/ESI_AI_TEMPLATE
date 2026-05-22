# Hub Architecture And Skill Governance

## Purpose

This document explains how the starter kit should connect to the rest of an AI hub and how future models or agents should discover approved skills. The goal is to create a controlled cycle where new skills are proposed in Git, reviewed by security and business owners, deployed into the skill registry, and then made available to agents only after approval.

## Architecture Layers

| Layer | Responsibility | Current Implementation |
| --- | --- | --- |
| Consumption layer | Where end users or agents interact with AI. | SharePoint, Microsoft 365, Teams, Power Automate, Office add-ins, Copilot extensions, or Hermes-style agents. |
| API control layer | Central policy and routing layer. | FastAPI app hosted in Azure Container Apps. |
| Document knowledge layer | Stores and retrieves approved business documents. | Azure Blob Storage plus Azure AI Search readiness. |
| Skill registry layer | Stores approved skills, skill groups, metadata, and future embeddings. | Cosmos DB for NoSQL with vector search enabled. |
| Model layer | Provides LLM and embedding capabilities. | Azure OpenAI / Azure AI Foundry placeholders. |
| Observability layer | Measures usage, quality, latency, and operational health. | Application Insights and Log Analytics. |
| Governance layer | Controls which skills and data sources can be used. | Git-based skill manifests, CI/CD validation, security review, and approved deployment stages. |

## How The Hub Connects

The hub should treat this API as a governed backend service, not as a one-off demo endpoint.

1. A user works in SharePoint, Teams, Office, Power Automate, Copilot, or Hermes.
2. The user-facing channel sends a request to the FastAPI service.
3. The API decides whether the request needs document retrieval, skill lookup, model completion, or human escalation.
4. For document questions, the API searches Azure AI Search.
5. For skill/tool selection, the API searches Cosmos DB skill registry by metadata and vector similarity.
6. For generation, the API calls the approved Azure OpenAI / Azure AI Foundry deployment.
7. The API logs telemetry for security, audit, quality, and KPI tracking.
8. The result returns to the original business surface.

## What A Future Model Or Agent Needs To Know

A future model should not guess how to connect to the hub. It needs explicit connection contracts.

### Required Environment Values

| Value | Purpose |
| --- | --- |
| `AZURE_STORAGE_ACCOUNT_NAME` | Storage account for uploaded source documents. |
| `AZURE_STORAGE_DOCUMENT_CONTAINER` | Blob container for document uploads. |
| `AZURE_SEARCH_ENDPOINT` | Azure AI Search endpoint for RAG retrieval. |
| `AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT` | Cosmos DB endpoint for skill lookup. |
| `AZURE_COSMOS_SKILL_REGISTRY_DATABASE` | Skill registry database name. |
| `AZURE_COSMOS_SKILL_REGISTRY_CONTAINER` | Skill registry container name. |
| `AZURE_KEY_VAULT_URI` | Future governed secret/config store. |
| `AZURE_OPENAI_ENDPOINT` | Approved model endpoint. |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Approved chat model deployment. |
| `AZURE_OPENAI_API_VERSION` | API version for model calls. |

### Required API Contracts

| Endpoint | Future Purpose |
| --- | --- |
| `GET /health` | Check whether the service is alive. |
| `GET /metrics` | Return KPI and operational metrics. |
| `POST /upload` | Accept approved documents for future ingestion. |
| `POST /ask` | Answer business questions using retrieval and model calls. |
| `POST /skills/search` | Find relevant approved skills from natural language. |
| `POST /skills/groups` | Return department/task skill bundles for agent routing. |

### Required Identity Pattern

- Use managed identity for Azure service access.
- Do not give agents direct Azure OpenAI keys.
- Do not put secrets in skill manifests.
- Use Key Vault only for values that cannot be represented through managed identity.
- Apply role-based access so agents only see skill groups they are allowed to use.

## Skill Lifecycle

Skills should move through a controlled lifecycle before agents can execute them.

| State | Meaning | Who Can Move It Forward |
| --- | --- | --- |
| Draft | A proposed skill exists in Git but is not trusted. | Skill author |
| Business reviewed | The business owner agrees the skill solves a valid workflow. | Department owner |
| Security reviewed | Security validates data access, permissions, risk level, and audit requirements. | Security team |
| Approved | The skill can be deployed to the registry and used by allowed agents. | Governance approver |
| Deprecated | The skill should not be used for new executions but remains auditable. | Governance approver |
| Revoked | The skill is blocked because of risk, incident, or policy change. | Security or governance approver |

## Git-Based Skill CI/CD Pipeline

The skill pipeline should make Git the source of truth. The skill registry should only receive skills that pass automated checks and required human review.

### Branch And Pull Request Flow

1. Skill author creates or updates a skill manifest under `skills/catalog/`.
2. Pull request opens against `main`.
3. CI validates manifest structure, required fields, risk metadata, department ownership, and missing secrets.
4. Security team reviews risky skills and confirms allowlisted tools/data sources.
5. Business owner confirms the skill is useful and correctly grouped.
6. Approved pull request merges to `main`.
7. Deployment job publishes approved skills into Cosmos DB skill registry.
8. Agents discover approved skills through `/skills/search` or `/skills/groups`.
9. Telemetry records skill lookup and execution for future audits.

### Required Gates

| Gate | Automated Or Manual | Purpose |
| --- | --- | --- |
| Manifest validation | Automated | Prevent malformed skill records. |
| Secret scanning | Automated | Prevent credentials from entering Git. |
| Owner validation | Automated | Ensure each skill has business and technical owners. |
| Risk classification | Automated | Require risk level and approval rules. |
| Security review | Manual | Confirm permissions, data access, and abuse risk. |
| Business review | Manual | Confirm workflow value and correct department grouping. |
| Registry deployment | Automated after approval | Publish only approved skills. |
| Audit logging | Automated | Track who approved and when the skill became available. |

## Skill Manifest Rules

Every skill manifest should include:

- Stable `skillId`.
- Human-readable `name`.
- `department`.
- `taskType`.
- `agentType`.
- Clear `description`.
- `owners`.
- `riskLevel`.
- `requiresHumanApproval`.
- `allowedChannels`.
- `allowedDataSources`.
- `inputs` and `outputs`.
- `status`.
- `version`.

The CI pipeline should reject manifests that:

- Contain secrets or API keys.
- Have missing owners.
- Set `status` to `approved` without review metadata.
- Omit risk level.
- Allow all channels without explanation.
- Reference unapproved tools or data sources.

## Security Team Audit Model

Security should be able to answer:

- Which skills are approved right now?
- Which agents can use each skill?
- Which data sources can the skill access?
- Does the skill require human approval?
- Who approved the skill and when?
- What changed between skill versions?
- Which skills were used in a given incident window?

This is why skill manifests live in Git and approved skills are copied into Cosmos DB rather than being edited directly in the database.

## Future Deployment Job

The repository includes a validation workflow for skills. A future deployment job should:

1. Read approved skill manifests from `skills/catalog/`.
2. Generate or refresh skill embeddings.
3. Upsert skill records into Cosmos DB.
4. Upsert skill-group records.
5. Mark deployment metadata such as commit SHA and deployment timestamp.
6. Emit an audit artifact for security review.

## Current Status

Implemented now:

- Skill registry infrastructure in Cosmos DB.
- API placeholder contracts for skill search and groups.
- Skill manifest examples.
- Skill validation script.
- CI workflow for validating skill manifests.

Still TODO:

- Real Cosmos DB upsert job.
- Embedding generation for skill descriptions.
- Required GitHub branch protection and CODEOWNERS.
- Security team approval environment.
- Agent runtime enforcement of approved skills only.
