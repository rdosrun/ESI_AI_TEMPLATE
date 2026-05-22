#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${AZURE_ENV_NAME:-}" ]]; then
  ENVIRONMENT_NAME="$AZURE_ENV_NAME"
else
  ENVIRONMENT_NAME="$(azd env get-values | sed -n 's/^AZURE_ENV_NAME="\(.*\)"$/\1/p')"
fi

if [[ -z "$ENVIRONMENT_NAME" ]]; then
  echo "Could not determine the azd environment name." >&2
  echo "Set AZURE_ENV_NAME explicitly, for example: AZURE_ENV_NAME=redeploy ./scripts/teardown-azd.sh" >&2
  exit 1
fi

echo "This will delete and purge Azure resources for azd environment: ${ENVIRONMENT_NAME}"
echo "Use this when the demo environment is no longer needed to avoid ongoing Azure costs."
read -r -p "Type '${ENVIRONMENT_NAME}' to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "$ENVIRONMENT_NAME" ]]; then
  echo "Teardown cancelled."
  exit 1
fi

azd env select "$ENVIRONMENT_NAME"
azd down --purge --force
