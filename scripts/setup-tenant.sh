#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ENVIRONMENT_NAME="${AZURE_ENV_NAME:-dev}"
AZURE_REGION="${AZURE_LOCATION:-eastus}"
BUILDER_REGION="${AGENT_BUILDER_LOCATION:-eastus2}"
TENANT_ID="${AZURE_TENANT_ID:-}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
DEPLOY_MODEL="${DEPLOY_AI_MODEL:-false}"
USE_DEVICE_CODE="${AZD_USE_DEVICE_CODE:-false}"
INTERACTIVE="true"
MODEL_OPTION_SET="false"
API_ALLOWED_HOSTS="${AGENT_API_ALLOWED_HOSTS:-}"

usage() {
  cat <<'EOF'
Configure an Azure tenant and deploy the complete starter kit with azd.

Usage:
  ./scripts/setup-tenant.sh
  ./scripts/setup-tenant.sh --tenant-id TENANT --subscription-id SUBSCRIPTION [options]

The script prompts for these values when run in a terminal. They can also be supplied
as options or matching environment variables:

  --tenant-id VALUE            Microsoft Entra tenant ID or verified domain
                               Environment: AZURE_TENANT_ID
  --subscription-id VALUE      Azure subscription ID
                               Environment: AZURE_SUBSCRIPTION_ID

Options:
  --environment VALUE          azd environment name (default: dev)
  --location VALUE             Main Azure region (default: eastus)
  --builder-location VALUE     Static Web Apps region (default: eastus2)
  --deploy-ai-model            Provision the configured Azure OpenAI model
  --existing-ai-endpoint URL   Use an existing approved Azure OpenAI endpoint
  --model-deployment VALUE     Existing or new model deployment name
  --model-name VALUE           Model name when provisioning a model
  --model-version VALUE        Model version when provisioning a model
  --api-allowed-hosts VALUE    Comma-separated public HTTPS hosts API blocks may call
  --device-code                Use device-code authentication
  --non-interactive            Disable the setup prompts; required values must be set
  -h, --help                   Show this help

Examples:
  ./scripts/setup-tenant.sh

  ./scripts/setup-tenant.sh \
    --tenant-id 00000000-0000-0000-0000-000000000000 \
    --subscription-id 11111111-1111-1111-1111-111111111111

  AZURE_TENANT_ID=contoso.onmicrosoft.com \
  AZURE_SUBSCRIPTION_ID=11111111-1111-1111-1111-111111111111 \
  ./scripts/setup-tenant.sh --deploy-ai-model

The script stores non-secret deployment settings in the ignored .azure directory.
It never asks for or writes application secrets.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but was not found on PATH."
}

prompt_value() {
  local prompt="$1"
  local current_value="$2"
  local answer

  if [[ -n "$current_value" ]]; then
    read -r -p "${prompt} [${current_value}]: " answer
    printf '%s' "${answer:-$current_value}"
  else
    read -r -p "${prompt}: " answer
    printf '%s' "$answer"
  fi
}

prompt_required() {
  local prompt="$1"
  local current_value="$2"
  local answer

  answer="$(prompt_value "$prompt" "$current_value")"
  while [[ -z "$answer" ]]; do
    echo "A value is required." >&2
    answer="$(prompt_value "$prompt" "")"
    if [[ -z "$answer" ]]; then
      continue
    fi
  done

  printf '%s' "$answer"
}

prompt_yes_no() {
  local prompt="$1"
  local default_value="$2"
  local suffix="[y/N]"
  local answer

  if [[ "$default_value" == "true" ]]; then
    suffix="[Y/n]"
  fi

  while true; do
    read -r -p "${prompt} ${suffix}: " answer
    answer="${answer:-$default_value}"
    case "${answer,,}" in
      y|yes|true) printf 'true'; return ;;
      n|no|false) printf 'false'; return ;;
      *) echo "Enter yes or no." >&2 ;;
    esac
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant-id)
      [[ $# -ge 2 ]] || fail "--tenant-id requires a value."
      TENANT_ID="$2"
      shift 2
      ;;
    --subscription-id)
      [[ $# -ge 2 ]] || fail "--subscription-id requires a value."
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --environment)
      [[ $# -ge 2 ]] || fail "--environment requires a value."
      ENVIRONMENT_NAME="$2"
      shift 2
      ;;
    --location)
      [[ $# -ge 2 ]] || fail "--location requires a value."
      AZURE_REGION="$2"
      shift 2
      ;;
    --builder-location)
      [[ $# -ge 2 ]] || fail "--builder-location requires a value."
      BUILDER_REGION="$2"
      shift 2
      ;;
    --deploy-ai-model)
      DEPLOY_MODEL="true"
      MODEL_OPTION_SET="true"
      shift
      ;;
    --existing-ai-endpoint)
      [[ $# -ge 2 ]] || fail "--existing-ai-endpoint requires a value."
      AZURE_OPENAI_ENDPOINT="$2"
      DEPLOY_MODEL="false"
      MODEL_OPTION_SET="true"
      shift 2
      ;;
    --model-deployment)
      [[ $# -ge 2 ]] || fail "--model-deployment requires a value."
      AZURE_OPENAI_DEPLOYMENT_NAME="$2"
      shift 2
      ;;
    --model-name)
      [[ $# -ge 2 ]] || fail "--model-name requires a value."
      AZURE_OPENAI_MODEL_NAME="$2"
      shift 2
      ;;
    --model-version)
      [[ $# -ge 2 ]] || fail "--model-version requires a value."
      AZURE_OPENAI_MODEL_VERSION="$2"
      shift 2
      ;;
    --api-allowed-hosts)
      [[ $# -ge 2 ]] || fail "--api-allowed-hosts requires a value."
      API_ALLOWED_HOSTS="$2"
      shift 2
      ;;
    --device-code)
      USE_DEVICE_CODE="true"
      shift
      ;;
    --non-interactive)
      INTERACTIVE="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option '$1'. Run with --help for usage."
      ;;
  esac
done

if [[ "$INTERACTIVE" == "true" && -t 0 ]]; then
  echo "Azure tenant setup"
  echo "Press Enter to accept a value shown in brackets."
  echo

  TENANT_ID="$(prompt_required "Microsoft Entra tenant ID or verified domain" "$TENANT_ID")"
  SUBSCRIPTION_ID="$(prompt_required "Azure subscription ID" "$SUBSCRIPTION_ID")"
  ENVIRONMENT_NAME="$(prompt_required "azd environment name" "$ENVIRONMENT_NAME")"
  AZURE_REGION="$(prompt_required "Main Azure region" "$AZURE_REGION")"
  BUILDER_REGION="$(prompt_required "Agent Builder Static Web Apps region" "$BUILDER_REGION")"
  USE_DEVICE_CODE="$(prompt_yes_no "Use device-code authentication?" "$USE_DEVICE_CODE")"
  API_ALLOWED_HOSTS="$(prompt_value "Allowed API hosts (comma-separated, blank for none)" "$API_ALLOWED_HOSTS")"

  if [[ "$MODEL_OPTION_SET" == "false" ]]; then
    echo
    echo "AI model configuration:"
    echo "  1) No model yet"
    echo "  2) Connect an existing approved Azure OpenAI endpoint"
    echo "  3) Provision a model deployment"
    read -r -p "Choose an option [1]: " MODEL_CHOICE
    MODEL_CHOICE="${MODEL_CHOICE:-1}"

    case "$MODEL_CHOICE" in
      1)
        DEPLOY_MODEL="false"
        ;;
      2)
        DEPLOY_MODEL="false"
        AZURE_OPENAI_ENDPOINT="$(prompt_required "Existing Azure OpenAI endpoint URL" "${AZURE_OPENAI_ENDPOINT:-}")"
        AZURE_OPENAI_DEPLOYMENT_NAME="$(prompt_required "Existing model deployment name" "${AZURE_OPENAI_DEPLOYMENT_NAME:-}")"
        ;;
      3)
        DEPLOY_MODEL="true"
        AZURE_OPENAI_DEPLOYMENT_NAME="$(prompt_required "New model deployment name" "${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o-mini}")"
        AZURE_OPENAI_MODEL_NAME="$(prompt_required "Model name" "${AZURE_OPENAI_MODEL_NAME:-gpt-4o-mini}")"
        AZURE_OPENAI_MODEL_VERSION="$(prompt_required "Model version" "${AZURE_OPENAI_MODEL_VERSION:-2024-07-18}")"
        ;;
      *)
        fail "Model choice must be 1, 2, or 3."
        ;;
    esac
  fi

  echo
  echo "Configuration summary"
  echo "  Tenant:              ${TENANT_ID}"
  echo "  Subscription:        ${SUBSCRIPTION_ID}"
  echo "  Environment:         ${ENVIRONMENT_NAME}"
  echo "  Main region:         ${AZURE_REGION}"
  echo "  Agent Builder region:${BUILDER_REGION}"
  echo "  Provision AI model:  ${DEPLOY_MODEL}"
  echo "  Allowed API hosts:   ${API_ALLOWED_HOSTS:-none}"
  echo

  CONFIRM_DEPLOY="$(prompt_yes_no "Continue and deploy Azure resources?" "false")"
  [[ "$CONFIRM_DEPLOY" == "true" ]] || {
    echo "Setup cancelled. No Azure resources were deployed."
    exit 0
  }
elif [[ "$INTERACTIVE" == "true" ]]; then
  echo "No interactive terminal detected; continuing in non-interactive mode."
fi

[[ -n "$TENANT_ID" ]] || fail "Provide --tenant-id, set AZURE_TENANT_ID, or run interactively."
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Provide --subscription-id, set AZURE_SUBSCRIPTION_ID, or run interactively."
[[ "$DEPLOY_MODEL" == "true" || "$DEPLOY_MODEL" == "false" ]] || fail "DEPLOY_AI_MODEL must be 'true' or 'false'."

require_command azd
require_command flutter
require_command docker

docker info >/dev/null 2>&1 || fail "Docker is installed but its daemon is not running. The API image build requires Docker."

cd "$REPO_ROOT"

echo "Signing azd into tenant: ${TENANT_ID}"
if [[ "$USE_DEVICE_CODE" == "true" ]]; then
  azd auth login --tenant-id "$TENANT_ID" --use-device-code
else
  azd auth login --tenant-id "$TENANT_ID"
fi

if azd env select "$ENVIRONMENT_NAME" >/dev/null 2>&1; then
  echo "Using existing azd environment: ${ENVIRONMENT_NAME}"
else
  echo "Creating azd environment: ${ENVIRONMENT_NAME}"
  azd env new "$ENVIRONMENT_NAME" \
    --location "$AZURE_REGION" \
    --subscription "$SUBSCRIPTION_ID"
fi

azd env set AZURE_TENANT_ID "$TENANT_ID"
azd env set AZURE_SUBSCRIPTION_ID "$SUBSCRIPTION_ID"
azd env set AZURE_LOCATION "$AZURE_REGION"
azd env set AGENT_BUILDER_LOCATION "$BUILDER_REGION"
azd env set DEPLOY_AI_MODEL "$DEPLOY_MODEL"
azd env set AGENT_API_ALLOWED_HOSTS "$API_ALLOWED_HOSTS"

if [[ -n "${AZURE_OPENAI_ENDPOINT:-}" ]]; then
  azd env set AZURE_OPENAI_ENDPOINT "$AZURE_OPENAI_ENDPOINT"
fi
if [[ -n "${AZURE_OPENAI_DEPLOYMENT_NAME:-}" ]]; then
  azd env set AZURE_OPENAI_DEPLOYMENT_NAME "$AZURE_OPENAI_DEPLOYMENT_NAME"
fi
if [[ -n "${AZURE_OPENAI_MODEL_NAME:-}" ]]; then
  azd env set AZURE_OPENAI_MODEL_NAME "$AZURE_OPENAI_MODEL_NAME"
fi
if [[ -n "${AZURE_OPENAI_MODEL_VERSION:-}" ]]; then
  azd env set AZURE_OPENAI_MODEL_VERSION "$AZURE_OPENAI_MODEL_VERSION"
fi

echo "Deploying infrastructure, the FastMCP API, and the Agent Builder."
azd up

echo
echo "Deployment complete. The service URLs are shown in the azd deployment output above."
echo "Use 'azd deploy agent-builder' to publish later Flutter-only changes."
echo "Use './scripts/teardown-azd.sh' when the environment is no longer needed."
