#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/openai/openai-openapi.git"
REF="refs/heads/master"

GIT_ROOT="$(git rev-parse --show-toplevel)"
COMMIT_FILE="$GIT_ROOT/Sources/OpenAIModels/openapi.commit"

# Ensure we have a local commit recorded
if [[ ! -f "$COMMIT_FILE" ]]; then
  echo "❌ Missing local commit file: $COMMIT_FILE" >&2
  exit 1
fi

LOCAL_SHA="$(< "$COMMIT_FILE")"

# Fetch remote SHA
REMOTE_SHA="$(git ls-remote "$REPO" "$REF" | awk '{print $1}')"
if [[ -z "$REMOTE_SHA" ]]; then
  echo "❌ Failed to resolve remote SHA for $REF" >&2
  exit 1
fi

# Compare and report
if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
  echo "✅ openapi.yaml is up-to-date (commit $LOCAL_SHA)"
  exit 0
else
  echo "⚠️  openapi.yaml is outdated:"
  echo "    local:  $LOCAL_SHA"
  echo "    remote: $REMOTE_SHA"
  exit 1
fi
