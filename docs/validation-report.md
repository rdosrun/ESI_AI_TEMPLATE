# Validation Report

Date: 2026-05-22

## Summary

The Azure AI Solutions Architect starter kit has been validated locally, built with Docker Buildx, provisioned with Azure Developer CLI, deployed successfully to Azure Container Apps, torn down, and redeployed into a fresh environment.

Current deployed API endpoint:

```text
https://esi-ai-redeploy-api.happygrass-825ca34c.eastus.azurecontainerapps.io
```

Resource group:

```text
rg-redeploy
```

## Environment

| Tool | Status | Evidence |
| --- | --- | --- |
| Azure CLI | Passed | Active subscription: `Azure subscription 1` / `840090d5-51f2-42bf-9d40-c2263855a810` |
| Azure Developer CLI | Passed | `azd version 1.25.0` |
| Bicep CLI | Passed | `az bicep build --file infra/main.bicep` completed |
| Docker daemon | Passed | `docker info` succeeded |
| Docker Buildx | Passed | `github.com/docker/buildx 0.34.1` |

## Local Validation Results

| Check | Status | Evidence |
| --- | --- | --- |
| Python syntax | Passed | `python -m py_compile src/api/main.py` |
| Shell scripts | Passed | `bash -n scripts/run-local.sh`, `bash -n scripts/docker-local.sh`, `bash -n scripts/deploy-azd.sh` |
| Docker Buildx build | Passed | `./scripts/docker-local.sh` built `esi-ai-api:local` |
| Docker container run | Passed | Container started on port `8000` |
| Local `/health` | Passed | Returned `{"status":"ok","service":"esi-ai-api"}` |
| Local `/metrics` | Passed | Returned KPI placeholder payload |
| Local `/skills/search` | Passed | Returned marketing skill lookup placeholder results |
| Local `/skills/groups` | Passed | Returned marketing content creation and analysis skill groups |

## Azure Deployment Results

| Check | Status | Evidence |
| --- | --- | --- |
| Bicep build | Passed with warnings | Cosmos DB vector schema warnings only |
| Initial azd environment | Passed | Environment `dev`, location `eastus` |
| Initial Azure provisioning | Passed after fix | `azd up --no-prompt` completed for `dev` |
| Teardown | Passed with long provider wait | `rg-dev` was deleted; Cosmos DB took the longest to clear |
| Redeploy azd environment | Passed | Environment `redeploy`, location `eastus` |
| Redeployment | Passed | `azd up --no-prompt` completed for `redeploy` |
| Container image publish | Passed | Image pushed to ACR |
| Container App deployment | Passed | API deployed to Azure Container Apps |
| Redeployed `/health` | Passed | Returned `{"status":"ok","service":"esi-ai-api"}` |
| Redeployed `/metrics` | Passed | Returned KPI placeholder payload |
| Redeployed `/upload` | Passed | Returned `accepted_placeholder` with redeployed storage account/container values |
| Redeployed `/ask` | Passed | Returned placeholder answer contract |
| Redeployed `/skills/search` | Passed | Returned placeholder results and confirmed Cosmos env values are configured |
| Redeployed `/skills/groups` | Passed | Returned skill group placeholders |

## Azure Resource Outputs

| Output | Value |
| --- | --- |
| API URL | `https://esi-ai-redeploy-api.happygrass-825ca34c.eastus.azurecontainerapps.io` |
| Resource group | `rg-redeploy` |
| Location | `eastus` |
| Container registry | `esiairedeployxe776zf4mfni6acr.azurecr.io` |
| Storage account | `esiairedeployxe776zf4mfn` |
| Document container | `uploaded-documents` |
| Azure AI Search endpoint | `https://esi-ai-redeploy-search.search.windows.net` |
| Key Vault URI | `https://esiairedeployxe776zf4mfn.vault.azure.net/` |
| Cosmos skill registry endpoint | `https://esiairedeployxe776zf4mfni6skills.documents.azure.com:443/` |
| Cosmos skill registry database | `agent-skills` |
| Cosmos skill registry container | `skills` |

## Teardown And Redeploy Result

The `dev` environment teardown was started with [scripts/teardown-azd.sh](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/scripts/teardown-azd.sh). Most resources deleted quickly, but the Cosmos DB account stayed in `Deleting` for several minutes. After the Cosmos account disappeared, Azure reported `rg-dev` as deleted.

To avoid waiting indefinitely on resource-group deletion propagation before proving repeatable deployment, a fresh azd environment named `redeploy` was created and deployed successfully.

## Issue Found And Fixed

Initial `azd up` failed on Key Vault:

```text
BadRequest: The property "enablePurgeProtection" cannot be set to false.
```

Fix applied:

- Updated [infra/modules/key-vault.bicep](/home/richardh/Documents/interview_prep/ESI/ESI_AI_TEMPLATE/infra/modules/key-vault.bicep) to set `enablePurgeProtection: true`.
- Re-ran Bicep build.
- Re-ran `azd up --no-prompt`.
- Deployment succeeded.

## Known Warnings

Bicep still reports type warnings for Cosmos DB vector search properties:

```text
The property "vectorIndexes" is not allowed on objects of type "IndexingPolicy".
The property "vectorEmbeddingPolicy" is not allowed on objects of type "SqlContainerResourceOrSqlContainerGetPropertiesResource".
```

The Azure deployment succeeded despite these warnings, so they appear to be Bicep type-definition warnings for newer Cosmos DB vector search schema support.

## Remaining Implementation TODOs

- Persist `/upload` files to Azure Blob Storage.
- Create document extraction, chunking, and Azure AI Search indexing.
- Wire `/ask` to Azure AI Search plus Azure OpenAI / Azure AI Foundry.
- Add Cosmos SDK implementation for `/skills/search` and `/skills/groups`.
- Seed Cosmos DB with starter skill and skill-group records.
- Add authentication and role-based access.
- Add tests for API contracts and deployment smoke checks.
- Add budget alerts or run `azd down --purge` when the demo environment is no longer needed.

## Useful Commands

Validate locally:

```bash
python -m py_compile src/api/main.py
bash -n scripts/run-local.sh
bash -n scripts/docker-local.sh
bash -n scripts/deploy-azd.sh
az bicep build --file infra/main.bicep
```

Run Docker locally:

```bash
./scripts/docker-local.sh
```

Deploy:

```bash
azd up --no-prompt
```

Tear down billable Azure resources:

```bash
./scripts/teardown-azd.sh
```
