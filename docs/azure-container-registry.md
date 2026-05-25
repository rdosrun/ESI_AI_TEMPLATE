# Azure Container Registry

## Purpose

This starter kit uses Azure Container Registry (ACR) as the controlled image store for the FastAPI service. The business reason is repeatability: the team can build the API once, store the approved image in Azure, and deploy that same artifact to Azure Container Apps.

## How This Repo Uses ACR

- `src/api/Dockerfile` defines the API image.
- `scripts/docker-local.sh` builds and runs the image locally with Docker Buildx.
- `azure.yaml` tells Azure Developer CLI to build and deploy the API service image.
- `infra/modules/container-registry.bicep` creates the Azure Container Registry resource.
- `infra/modules/container-app.bicep` configures Azure Container Apps to pull the API image.

Azure Developer CLI publishes the service image during deployment. Azure Container Apps then runs the approved image by reference. This gives the demo a clean separation between source code, build artifact, and running service.

## Registry Security

- ACR admin user access is disabled.
- The API managed identity receives `AcrPull` so Container Apps can pull images without registry passwords.
- The Basic SKU keeps the demo cost-conscious while still showing a real image promotion path.
- TODO: Add image scanning and promotion gates before production use.

## Image Metadata

The API Dockerfile includes image labels so scanners, registries, and release tooling can identify the image purpose and documentation.

Current labels:

- `com.azure.containerregistry.image.title`
- `com.azure.containerregistry.image.description`
- `com.azure.containerregistry.image.vendor`
- `com.azure.containerregistry.image.source`
- `com.azure.containerregistry.image.documentation`
- `com.azure.containerregistry.image.licenses`

TODO: Replace the placeholder source URL and confirm the license before publishing this image outside the demo repository.

## Interview Talking Points

- ACR provides a private Azure-native registry for approved container images.
- Azure Container Apps pulls the image with managed identity, avoiding registry passwords.
- The same image can be promoted from demo to test to production after validation.
- Image metadata improves auditability for security, operations, and release review.

## Validation Commands

Build and run locally:

```bash
./scripts/docker-local.sh
```

Inspect image labels:

```bash
docker image inspect esi-ai-api:local \
  --format '{{ json .Config.Labels }}'
```

Validate the deployed image reference after `azd up`:

```bash
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group-name> \
  --query properties.template.containers[0].image
```
