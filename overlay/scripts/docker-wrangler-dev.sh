#!/bin/sh
set -eu

PERSIST_DIR="${WRANGLER_PERSIST_DIR:-/data/wrangler-state}"
PORT="${WRANGLER_PORT:-8787}"
IP="${WRANGLER_IP:-0.0.0.0}"

mkdir -p "$PERSIST_DIR"

exec npx wrangler dev --local --ip "$IP" --port "$PORT" --persist-to "$PERSIST_DIR"
