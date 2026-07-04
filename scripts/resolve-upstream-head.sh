#!/bin/sh
set -eu

BRANCH="${1:-main}"
API_URL="https://api.github.com/repos/shuaiplus/nodewarden/commits/${BRANCH}"

commit_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$API_URL")"
sha="$(printf '%s' "$commit_json" | jq -r '.sha')"

if [ -z "$sha" ] || [ "$sha" = "null" ]; then
  echo "failed to resolve upstream head sha for branch $BRANCH" >&2
  exit 1
fi

short_sha="$(printf '%s' "$sha" | cut -c1-7)"

printf 'upstream_branch=%s\n' "$BRANCH"
printf 'upstream_sha=%s\n' "$sha"
printf 'upstream_short_sha=%s\n' "$short_sha"
