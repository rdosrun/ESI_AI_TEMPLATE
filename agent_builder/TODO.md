# Agent Builder Implementation TODOs

This roadmap turns the current Flutter prototype into a governed builder that can save, test, and deploy approved agents. Complete the phases in order because deployment depends on identity, validation, persistence, and authorization.

## 1. Formalize and validate the architecture contract

Business outcome: users receive useful errors before saving or deploying an invalid workflow.

- [x] Add `schemas/agent-architecture.schema.json` for schema version `1.0`.
- [x] Define the initial required node and edge document structure.
- [ ] Extend validation for type-specific conditions, URL schemes, request size, and credential-reference formats. IDs and edge references are validated now.
- [x] Add a schema migration policy before introducing version `2.0`.
- [ ] Show validation errors beside the affected Flutter block and in a summary panel.
- [ ] Add Dart unit tests for valid, invalid, and older architecture documents.

Hookup:

1. Keep JSON serialization in `lib/main.dart` compatible with the schema.
2. Add a reusable Flutter validation service under `lib/services/` for immediate client feedback.
3. Run the same authoritative validation in the backend; client-side validation is not a security boundary.
4. Make validation a required CI check and reject invalid deploy requests with structured field errors.

## 2. Add Microsoft Entra ID sign-in

Business outcome: saved designs and deployments have a known owner and can be governed by role.

- [x] Add a **Sign in** control and signed-in user state to Flutter.
- [x] Configure built-in Microsoft Entra authentication for Azure Static Web Apps.
- [ ] Define roles such as `viewer`, `designer`, `reviewer`, and `deployer`.
- [x] Require authentication before cloud save and deployment. Apply the same rule to future sharing and connection testing.
- [ ] Keep local-only editing available only if the product owner wants an anonymous demo mode.

Hookup:

1. Flutter reads the authenticated user from the Static Web Apps authentication endpoint.
2. Flutter sends authenticated requests only to the approved architecture API route.
3. The API derives identity and roles from validated claims; it must not trust an owner ID supplied in JSON.
4. Bicep configures allowed identity providers and API origins after the tenant and app-registration details are approved.

TODO: Confirm the customer tenant, allowed user groups, and whether production access requires private networking.

## 3. Add cloud save, version history, and sharing

Business outcome: designs survive browser changes, can be reviewed, and have an audit trail.

- [ ] Complete **Open**, **Save as**, and version-history screens. **Save to cloud** is implemented.
- [ ] Keep browser storage as draft recovery, not the system of record.
- [ ] Add optimistic concurrency so one user cannot silently overwrite another user's changes.
- [ ] Replace the demo owner with authenticated ownership and add approval metadata. Version, status, and timestamps are implemented.
- [ ] Add explicit sharing controls rather than sharing raw storage links.

Hookup:

1. Add authenticated HTTP endpoints such as `POST /architectures`, `GET /architectures/{id}`, and `PUT /architectures/{id}` to a dedicated architecture API or a clearly separated API router.
2. The API validates and authorizes every request, then stores documents and version metadata in Cosmos DB.
3. The API uses managed identity; Flutter never receives Cosmos DB keys or connection strings.
4. Flutter stores only the returned architecture ID and version locally.

TODO: Decide whether architecture CRUD belongs beside the FastMCP service or in a separate small FastAPI service. Keep conventional browser CRUD separate from MCP tool transport at the route level.

## 4. Connect the planning chat

Business outcome: users can receive design help grounded in approved platform rules without exposing model credentials.

- [ ] Replace the local placeholder with streamed chat responses.
- [ ] Let users choose whether to send the current architecture as context.
- [ ] Show citations or rule references when recommendations use governed documentation.
- [ ] Add clear error, retry, cancel, and rate-limit states.
- [ ] Do not log full prompts or architecture content by default.

Hookup:

1. Flutter calls an authenticated backend chat endpoint; it never calls the model using a browser-held key.
2. The backend uses managed identity to call the approved Azure AI Foundry model deployment.
3. The backend filters the architecture context, enforces content and size limits, and streams safe response events to Flutter.
4. Application Insights records latency, failures, and token/cost metrics without secrets or sensitive prompt bodies.

TODO: Confirm the approved model, region, deployment name, content-safety policy, and retention requirements.

## 5. Add connection testing for API and MCP blocks

Business outcome: designers can prove integrations work before asking for deployment approval.

- [ ] Add **Test connection** and display sanitized results for API and MCP blocks.
- [ ] Validate that an MCP server can initialize and list the configured tool.
- [ ] Validate API method, URL, timeout, and expected response shape.
- [ ] Prevent the browser from calling arbitrary user-entered endpoints directly.

Hookup:

1. Flutter sends a test request containing the integration metadata and a credential reference.
2. A trusted backend checks the caller's permission and an endpoint allowlist.
3. The backend resolves approved secrets from Key Vault using managed identity and performs the test server-side.
4. The response returns only status, latency, and a sanitized error; it never returns credentials or sensitive payloads.

TODO: Define outbound-network rules, approved domains, private endpoints, timeouts, and per-user rate limits.

## 6. Turn approved designs into deployable agents

Business outcome: a reviewed visual design can become a traceable agent deployment instead of remaining only an exported JSON file.

- [x] Extend the implemented `draft` state with an `active` live-runtime state.
- [ ] Protect the implemented deployment-request action with reviewer and deployer roles.
- [ ] Define which visual blocks are executable in the first release; reject unsupported graphs explicitly.
- [x] Compile approved architecture JSON into a versioned runtime manifest.
- [x] Store deployment ID, runtime version, source architecture version, status, and endpoint.
- [x] Add an owner-scoped deployed-agent search and invocation workspace.
- [x] Execute allowlisted API blocks server-side and ground the agent with their responses.
- [ ] Add rollback or redeploy from a previously approved version.

Hookup:

1. Flutter submits an architecture ID and exact version to `POST /architectures/{id}/deploy`; it does not send Azure credentials.
2. The deployment API re-loads the saved version, checks approval and the `deployer` role, validates integrations, and creates an immutable deployment record.
3. A deployment worker translates the approved manifest into the selected Azure AI agent/runtime resources using managed identity.
4. The worker stores runtime configuration references in Key Vault or the platform configuration store and reports status through the deployment API.
5. Flutter polls or subscribes to deployment status and shows the resulting endpoint and audit history.

TODO: Choose and document the supported runtime before implementing this phase. Confirm the Azure AI project/resource, agent API version, model deployment, tool authorization model, network boundary, quota, and deletion/rollback behavior. Do not let Flutter run Bicep, `azd`, Azure CLI, or ARM calls directly from the browser.

## 7. Add audit telemetry and production controls

Business outcome: operators can answer who changed or deployed an agent, diagnose failures, and control cost.

- [ ] Record create, update, import, export, test, review, approval, deployment, rollback, and deletion events.
- [ ] Add correlation IDs from Flutter through the API and deployment worker.
- [ ] Add accessible loading, keyboard, focus, and error states.
- [ ] Add Content Security Policy, restricted CORS, custom-domain, and privacy-notice decisions.
- [ ] Add budgets, rate limits, deployment concurrency limits, alerts, and operational dashboards.
- [ ] Add end-to-end tests for sign-in, save, review, deploy, status, and authorization failures.

Hookup:

1. Flutter sends a correlation ID and records only non-sensitive client events.
2. Backend services write structured audit and operational telemetry to Application Insights and Log Analytics.
3. Deployment records reference the actor, approval, source version, target environment, and Azure resource identifiers.
4. CI validates Flutter, the JSON schema, API contracts, Bicep, and authorization tests before deployment.

## Recommended first usable milestone

The first production-shaped milestone should include phases 1 through 3. It provides authenticated, validated, versioned architecture storage without prematurely claiming that visual workflows are executable. Add phase 5 before phase 6 so deployment cannot promote untested integrations.

Definition of done for agent deployment:

- An authenticated designer can save a schema-valid architecture.
- A different authorized reviewer can approve the exact saved version.
- Only a deployer can deploy that approved version to an allowed environment.
- Secrets remain in Key Vault and all Azure access uses managed identity.
- The UI shows deployment progress, endpoint, version, and sanitized failures.
- Audit history connects the deployed runtime to its source architecture and approval.
