#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-esi-ai-api:local}"

if ! docker buildx version >/dev/null 2>&1; then
  echo "Docker Buildx is required but is not installed or not available on PATH." >&2
  echo "Install the Docker Buildx component, then rerun this script." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed, but the Docker daemon is not reachable." >&2
  echo "Start Docker Desktop or the Docker daemon, then rerun this script." >&2
  exit 1
fi

docker buildx build --load -t "$IMAGE_NAME" src/api
docker run --rm -p 8000:8000 "$IMAGE_NAME"
