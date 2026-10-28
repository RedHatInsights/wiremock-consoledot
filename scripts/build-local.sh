#!/usr/bin/env bash
# Local image build using the same Dockerfile as Konflux (needs network for Maven JARs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE_TAG="${IMAGE_TAG:-wiremock-consoledot:local}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-}"

if [ -z "${CONTAINER_ENGINE}" ]; then
  if command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE=podman
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_ENGINE=docker
  else
    echo "Need podman or docker on PATH" >&2
    exit 1
  fi
fi

if [ ! -f vendor/grpc/kessel.dsc ]; then
  echo "Missing vendor/grpc/kessel.dsc. Run: ./scripts/refresh-vendor.sh" >&2
  exit 1
fi

echo "==> Building ${IMAGE_TAG} with ${CONTAINER_ENGINE} (Dockerfile)"
exec "${CONTAINER_ENGINE}" build -f Dockerfile -t "${IMAGE_TAG}" .
