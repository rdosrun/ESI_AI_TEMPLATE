# Demo Script

## Audience

Business stakeholders, delivery leads, and technical interviewers evaluating AI Solutions Architect readiness.

## Opening

"This starter kit shows how I would turn an AI idea into a repeatable proof of concept. It includes infrastructure as code, a Dockerized API, document storage, search readiness, model connection placeholders, observability, CI/CD awareness, and business-facing operating documents."

## Demo Steps

1. Show the README and explain the business problem.
2. Open the architecture document and walk through each Azure service in business terms.
3. Show `infra/main.bicep` and explain that resources are deployed repeatably with azd.
4. Show `src/api/main.py` and explain the current API contract.
5. Run `GET /health` to prove the service is alive.
6. Run `GET /metrics` to show KPI planning.
7. Run `POST /upload` with a sample document and explain the future ingestion path.
8. Run `POST /ask` and explain the future RAG path.
9. Run `POST /skills/search` and explain natural language skill lookup for agents.
10. Show the end-user consumption patterns for SharePoint, Microsoft 365, Power Automate, and Hermes.
11. Show the CI/CD workflow and explain validation before deployment.
12. Close with the production gaps and next steps.

## Talk Track For Placeholders

"The goal of this version is not to pretend the RAG system is finished. The goal is to create a clean contract and deployment foundation. The next implementation step is to connect Blob Storage, create a Search index, add chunking, call an approved model deployment, and evaluate answer quality."

## Talk Track For Microsoft 365 And Hermes

"End users should not need to open Azure or know how the model is hosted. They should use AI inside SharePoint, Teams, Office, Power Automate, or an agentic platform like Hermes. This API becomes the governed backend that those channels call, so we can keep retrieval, citations, telemetry, and policy controls consistent."

## Talk Track For Skill Registry

"The same department can need multiple agent behaviors. Marketing content creation and marketing analysis should not use the same tools or approval rules. The Cosmos DB skill registry gives agents a searchable catalog of approved skills, grouped by department and task, so natural language requests can route to the right capability."

## Closing Questions To Ask Stakeholders

- Which document set should we use first?
- What answer quality threshold would make this useful?
- Who approves the source content?
- What workflow should this integrate with after the pilot?
- What KPI would justify expanding the solution?
