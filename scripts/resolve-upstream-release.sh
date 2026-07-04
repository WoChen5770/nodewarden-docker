#!/bin/sh
set -eu

TAG="${1:?missing upstream release tag}"
API_URL="https://api.github.com/repos/shuaiplus/nodewarden/releases/tags/${TAG}"

release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$API_URL")"

target_commitish="$(printf '%s' "$release_json" | jq -r '.target_commitish')"
if [ -z "$target_commitish" ] || [ "$target_commitish" = "null" ]; then
  echo "failed to resolve target_commitish for release tag $TAG" >&2
  exit 1
fi

sha="$(git ls-remote https://github.com/shuaiplus/nodewarden.git "refs/tags/${TAG}^{}" | cut -f1)"
if [ -z "$sha" ]; then
  sha="$(git ls-remote https://github.com/shuaiplus/nodewarden.git "refs/tags/${TAG}" | cut -f1)"
fi

if [ -z "$sha" ]; then
  echo "failed to resolve commit sha for release tag $TAG" >&2
  exit 1
fi

printf 'upstream_tag=%s\n' "$TAG"
printf 'upstream_sha=%s\n' "$sha"
printf 'target_commitish=%s\n' "$target_commitish"
