# Requested Deliverables Checklist

This checklist maps the original requested items to the files added or updated.

- [x] Inspect current repo.
- [x] Create clean starter project structure.
- [x] Add/update `azure.yaml`.
- [x] Add/update `README.md`.
- [x] Add/update `.gitignore`.
- [x] Add/update `infra/main.bicep`.
- [x] Add/update `infra/main.parameters.json`.
- [x] Add/update `infra/modules/*.bicep`.
- [x] Add/update `src/api/main.py`.
- [x] Add/update `src/api/requirements.txt`.
- [x] Add/update `src/api/Dockerfile`.
- [x] Add/update `docs/architecture.md`.
- [x] Add/update `docs/stakeholder-discovery-template.md`.
- [x] Add/update `docs/sop-ai-intake-process.md`.
- [x] Add/update `docs/kpi-scorecard.md`.
- [x] Add/update `docs/vendor-evaluation-template.md`.
- [x] Add/update `docs/demo-script.md`.
- [x] Add/update `.github/workflows/deploy.yml`.
- [x] Keep first version deployable but simple.
- [x] Use clear parameters and TODO comments where service values are unknown.
- [x] Add business-purpose comments for Azure services.
- [x] Include `GET /health`.
- [x] Include `GET /metrics`.
- [x] Include `POST /upload` placeholder.
- [x] Include `POST /ask` placeholder.
- [x] Avoid real secrets and credentials.
- [x] Ignore local Azure state, environment files, and Codex session files.
- [x] Create additional agent review checklist files.
- [x] Add shell scripts for local run, Docker buildx run, and azd deployment commands.
- [x] Add teardown script for deleting and purging demo Azure resources.
- [x] Add end-user consumption documentation for SharePoint, Microsoft 365, and agentic platforms such as Hermes.
- [x] Add Cosmos DB vector skill registry infrastructure and docs.
- [x] Add API placeholders for natural language skill lookup and skill groups.
- [x] Add hub architecture and skill governance guide.
- [x] Add skill manifest examples and validation script.
- [x] Add skill governance CI workflow scaffold.

## Validation Still Needed

- [ ] Run Bicep build on a machine with Azure CLI installed.
- [ ] Run `azd up` in a controlled test subscription.
- [ ] Exercise the deployed API endpoint after Container Apps deployment.
