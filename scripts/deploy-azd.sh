#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT_NAME="${AZURE_ENV_NAME:-dev}"
AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

az login
azd auth login
az bicep build --file infra/main.bicep
azd env new "$ENVIRONMENT_NAME" || azd env select "$ENVIRONMENT_NAME"
azd env set AZURE_LOCATION "$AZURE_LOCATION"
azd up
