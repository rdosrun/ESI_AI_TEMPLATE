# End-User AI Consumption Patterns

The starter kit should let users consume AI through familiar business tools instead of asking them to learn a new standalone application. The FastAPI service remains the control layer, while Microsoft 365 and agentic platforms become user-facing channels.

## Recommended Channels

| Channel | How Users Consume AI | Starter Kit Role |
| --- | --- | --- |
| SharePoint document libraries | Users store SOPs, policies, training materials, and project documents where they already work. | Ingest approved SharePoint files into Blob Storage and Azure AI Search. |
| Microsoft Teams | Users ask questions in a team channel or personal assistant experience. | Teams bot or Copilot agent calls the `/ask` API. |
| Microsoft Word | Users summarize, compare, or draft content using approved source documents. | Office add-in or Microsoft 365 Copilot extension calls the API. |
| Microsoft Excel | Users ask questions about structured KPI exports, intake logs, or scorecards. | Office add-in or workflow connector sends table context to the API. |
| Microsoft PowerPoint | Users generate briefing drafts, demo talking points, or executive summaries. | Office add-in or agent sends source context to the API. |
| Power Automate | Users trigger AI steps inside business workflows. | Flow action calls `/upload`, `/ask`, or future evaluation endpoints. |
| Agentic orchestrator such as Hermes | An agent plans multi-step work, retrieves context, selects skills, calls tools, and escalates decisions. | Hermes calls this API as one governed AI tool and can use `/skills/search` for skill selection. |

## SharePoint And Microsoft 365 Pattern

1. A business team keeps approved documents in a SharePoint document library.
2. A scheduled or event-driven process identifies approved files.
3. The ingestion process copies document content or extracted text into Blob Storage.
4. Azure AI Search indexes the approved content.
5. Users ask questions from Teams, Office, Copilot, or another interface.
6. The user-facing channel calls the FastAPI `/ask` endpoint.
7. The API retrieves relevant indexed content and calls the approved model deployment.
8. The response returns an answer, citations, and next-step guidance.

## Office Product Integration Options

### Microsoft 365 Copilot Extension

Best for organizations already using Microsoft 365 Copilot. The API can be exposed as an action so users can ask grounded questions from Copilot experiences.

### Teams Bot

Best for demos and team workflows. Teams gives users a chat-based surface without building a full web app.

### Office Add-In

Best when the workflow lives inside Word, Excel, or PowerPoint. The add-in can call the API and insert results into the document, spreadsheet, or presentation.

### Power Automate Connector

Best for process automation. A flow can call the API when a document is uploaded, an intake request is submitted, or a KPI review is due.

## Agentic Orchestration Pattern

An agentic platform such as Hermes should not bypass governance. It should call the starter API as a controlled tool.

Example agent flow:

1. User asks Hermes to analyze an SOP or answer a process question.
2. Hermes decides whether it needs document retrieval, KPI context, or human escalation.
3. Hermes calls `/ask` with the question and workflow context.
4. Hermes can call `/skills/search` to find the right approved skill or skill group.
5. The API retrieves approved content and generates a grounded response.
6. Hermes uses the response to continue the workflow, draft an artifact, or ask for approval.
7. Telemetry is logged for adoption, quality, latency, and cost tracking.

## Skill Grouping Pattern

Agent skills should be grouped by department and task type so different agents behave differently even when they serve the same department.

Examples:

- Marketing social media post creator: draft post, brand voice check, hashtag suggestion, approval summary.
- Marketing analyst: campaign KPI summary, audience segment comparison, trend explanation, budget variance explanation.
- HR policy assistant: find policy, summarize changes, explain eligibility, escalate to HR owner.

## Governance Rules

- End users should not receive direct Azure OpenAI keys.
- SharePoint ingestion should only include approved libraries or folders.
- Answers should include citations before being trusted in SOP or LMS workflows.
- Sensitive documents should follow the organization classification and retention policy.
- Agentic tools should have explicit allowlists for actions they can take.
- Human approval should be required before high-impact actions.

## Implementation TODOs

- Add Microsoft Graph integration for SharePoint document ingestion.
- Add Azure AI Search index schema for SharePoint metadata, document title, source URL, owner, and modified date.
- Add Teams bot or Copilot extension manifest.
- Add Office add-in sample for Word or Excel.
- Add Power Automate custom connector definition.
- Add Hermes tool contract once the exact Hermes interface is confirmed.
- Add Cosmos DB-backed vector search for agent skill lookup and skill grouping.
