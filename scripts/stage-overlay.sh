#!/bin/sh
set -eu

UPSTREAM_DIR="${1:?missing upstream directory}"
REPO_ROOT="${2:?missing packaging repository root}"

mkdir -p "$UPSTREAM_DIR/scripts"

cp "$REPO_ROOT/overlay/Dockerfile.local" "$UPSTREAM_DIR/Dockerfile.local"
cp "$REPO_ROOT/overlay/.dockerignore" "$UPSTREAM_DIR/.dockerignore"
cp "$REPO_ROOT/overlay/scripts/docker-wrangler-dev.sh" "$UPSTREAM_DIR/scripts/docker-wrangler-dev.sh"

chmod +x "$UPSTREAM_DIR/scripts/docker-wrangler-dev.sh"
