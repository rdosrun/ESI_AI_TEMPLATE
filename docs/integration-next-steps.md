# Integration Next Steps

This checklist turns the README next steps into an ordered integration plan. The goal is to move the starter kit from interview-ready scaffolding to a working governed AI integration while keeping the demo easy to explain.

## 1. Confirm Integration Scope

- [ ] Pick the first business workflow to integrate, such as SOP question answering, marketing content support, or policy lookup.
- [ ] Identify the first end-user channel: Teams bot, Microsoft 365 Copilot extension, Office add-in, Power Automate connector, Hermes tool, or direct API consumer.
- [ ] Confirm the approved document source, owner, and update cadence.
- [ ] Define success metrics for the first workflow, including answer quality, citation coverage, adoption, time saved, and escalation rate.
- [ ] Document any data classification, retention, approval, or audit requirements before ingesting real content.

## 2. Configure Azure Model Access

- [ ] Confirm whether the approved model endpoint is Azure OpenAI or Azure AI Foundry.
- [ ] Create or identify the approved chat model deployment.
- [ ] Set `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`, and `AZURE_OPENAI_API_VERSION` through `azd env set`.
- [ ] Add TODO comments or documentation for any subscription-specific model limits, content filters, and responsible AI requirements.
- [ ] Validate that Container Apps receives the model configuration as environment variables.

## 3. Implement Document Ingestion

- [ ] Wire `POST /upload` to stream files into the provisioned Blob Storage container using managed identity.
- [ ] Add supported file type validation and clear rejection messages.
- [ ] Add document metadata, including source, owner, upload time, content type, and approval status.
- [ ] Add extraction and chunking for the initial document types.
- [ ] Decide whether SharePoint ingestion should run on a schedule, on change events, or through a manual sync command.
- [ ] Add Microsoft Graph integration for approved SharePoint libraries after tenant app registration details are confirmed.

## 4. Build Azure AI Search Retrieval

- [ ] Define the Azure AI Search index schema for chunks, citations, source URLs, document owners, modified dates, and security labels.
- [ ] Create the index, skillset or ingestion process, and indexer strategy.
- [ ] Push approved chunks into Azure AI Search from Blob Storage or the ingestion worker.
- [ ] Add retrieval code for `/ask`, including top-k search, filters, and citation source assembly.
- [ ] Add citation validation so generated answers only cite retrieved approved sources.

## 5. Wire Grounded Answer Generation

- [ ] Add the Azure SDK dependency needed for the chosen model endpoint.
- [ ] Build prompt assembly that includes user question, workflow context, retrieved chunks, and citation instructions.
- [ ] Call the approved model deployment from `/ask`.
- [ ] Return answer, status, next steps, and citations using the existing response contract.
- [ ] Add fallback behavior when no relevant content is found.
- [ ] Log latency, retrieval count, model readiness, and answer outcome to Application Insights.

## 6. Implement Agent Skill Registry

- [ ] Add the Cosmos DB SDK dependency.
- [ ] Seed Cosmos DB with approved skill and skill-group records from `skills/catalog`.
- [ ] Generate embeddings for skill descriptions after the embedding model is approved.
- [ ] Implement vector lookup in `POST /skills/search`.
- [ ] Implement group lookup in `POST /skills/groups`.
- [ ] Apply department, task type, channel, risk, and approval filters before returning executable skills.
- [ ] Log skill selection telemetry for audit and KPI reporting.

## 7. Add Security And Access Control

- [ ] Add authentication for business users or calling channels.
- [ ] Define role-based access rules for upload, ask, skill lookup, and admin operations.
- [ ] Ensure Storage, Search, Cosmos DB, and Key Vault access use managed identity where possible.
- [ ] Add secret handling guidance for any external channel credentials that cannot use managed identity.
- [ ] Confirm network, retention, audit, and data residency requirements for the target customer or demo tenant.

## 8. Integrate The First User Channel

- [ ] Create the first channel contract for Teams, Copilot extension, Office add-in, Power Automate, or Hermes.
- [ ] Map channel inputs to `/ask`, `/upload`, `/skills/search`, and `/skills/groups`.
- [ ] Decide how citations, confidence, and human escalation appear to end users.
- [ ] Add a demo-ready example request and response for the selected channel.
- [ ] Document channel-specific setup steps and tenant permissions.

## 9. Add Tests And Evaluation

- [ ] Add FastAPI contract tests for health, metrics, upload, ask, skill search, and skill groups.
- [ ] Add smoke tests for deployed Container Apps endpoints.
- [ ] Add ingestion tests with small approved sample documents.
- [ ] Create an evaluation dataset with expected answers, citations, and escalation cases.
- [ ] Track hallucination risk, citation coverage, refusal behavior, and answer usefulness.
- [ ] Add CI checks that validate Bicep, Python syntax, tests, and skill manifest schemas.

## 10. Prepare Operational Readiness

- [ ] Add budget alerts and cost review notes for Search, Cosmos DB, Log Analytics, model calls, and Container Apps.
- [ ] Add dashboards or saved queries for adoption, latency, failures, answer quality, and cost per answer.
- [ ] Add deployment promotion guidance for dev, test, and production environments.
- [ ] Add rollback and teardown instructions for demo environments.
- [ ] Update the demo script once real retrieval, model calls, skill lookup, and the first user channel are working.

## Recommended First Sprint

- [ ] Persist `/upload` files to Blob Storage.
- [ ] Create the first Azure AI Search index schema.
- [ ] Wire `/ask` to retrieve indexed chunks and return citations.
- [ ] Configure the approved model endpoint through `azd env set`.
- [ ] Add one channel contract, preferably Teams or Hermes if the interview story centers on agentic workflows.
- [ ] Add API contract tests before expanding the integration surface.

