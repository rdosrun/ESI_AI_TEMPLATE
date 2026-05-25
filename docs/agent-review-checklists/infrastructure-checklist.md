# Infrastructure Review Checklist

Use this checklist to review the Bicep and azd deployment work.

- [x] `azure.yaml` defines an Azure Developer CLI project.
- [x] `infra/main.bicep` composes the environment from modules.
- [x] Storage Account module exists.
- [x] Blob container for uploaded documents exists.
- [x] Azure AI Search module exists.
- [x] Cosmos DB skill registry module exists for vector skill lookup.
- [x] Azure OpenAI / Azure AI Foundry model values are placeholders, not hardcoded secrets.
- [x] Key Vault module exists.
- [x] Log Analytics module exists.
- [x] Application Insights module exists.
- [x] Container Apps Environment module exists.
- [x] Container App module exists.
- [x] Managed Identity module exists.
- [x] Container Registry module exists so Container Apps can run the approved API image.
- [x] Azure Container Registry documentation exists for image traceability.
- [x] Business-purpose comments were added near each Azure service.
- [x] No local Azure state is committed.

## Follow-Up Checks

- [ ] Run `az bicep build --file infra/main.bicep`.
- [ ] Run `azd provision` in a test subscription.
- [ ] Confirm Azure AI Search free SKU availability in the target subscription.
- [ ] Confirm Cosmos DB for NoSQL vector search availability in the target region.
- [ ] Confirm naming rules for the chosen azd environment name.
