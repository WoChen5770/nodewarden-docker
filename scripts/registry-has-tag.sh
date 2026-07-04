#!/bin/sh
set -eu

IMAGE_REF="${1:?missing image reference}"

if docker buildx imagetools inspect "$IMAGE_REF" >/dev/null 2>&1; then
  printf 'exists=true\n'
else
  printf 'exists=false\n'
fi
