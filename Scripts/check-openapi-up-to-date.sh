#!/usr/bin/env bash
set -euo pipefail

SPEC_URL="https://app.stainless.com/api/spec/documented/openai/openapi.documented.yml"

GIT_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_SPEC="$GIT_ROOT/Sources/OpenAIFoundation/openapi.yaml"

if [[ ! -f "$LOCAL_SPEC" ]]; then
  echo "❌ Missing local spec file: $LOCAL_SPEC" >&2
  exit 1
fi

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  fi
}

LOCAL_SHA="$(hash_file "$LOCAL_SPEC")"

TMP_REMOTE="$(mktemp)"
trap 'rm -f "$TMP_REMOTE"' EXIT

curl -fsSL "$SPEC_URL" -o "$TMP_REMOTE"
REMOTE_SHA="$(hash_file "$TMP_REMOTE")"

# Compare and report
if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
  echo "✅ openapi.yaml is up-to-date (sha256 $LOCAL_SHA)"
  exit 0
else
  echo "⚠️  openapi.yaml is outdated:"
  echo "    source: $SPEC_URL"
  echo "    local:  sha256 $LOCAL_SHA"
  echo "    remote: sha256 $REMOTE_SHA"
  exit 1
fi
